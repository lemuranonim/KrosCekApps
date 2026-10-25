"""Verify an existing signed release artifact, then publish only matching evidence."""
import io
import json
import os
import re
import sys
import urllib.request
import urllib.error
import urllib.parse
import zipfile

REPOSITORY='lemuranonim/KrosCekApps'
CHECKS=['old_key_initial_install','new_key_lineage_upgrade','application_data_preserved',
    'old_key_higher_version_rejected','real_app_upgrade_from_v4_9_8']

def number(name):
    value=os.environ[name]
    if not re.fullmatch(r'[1-9][0-9]*',value): raise RuntimeError('Invalid workflow run id')
    return int(value)

def github(path,method='GET',payload=None):
    request=urllib.request.Request('https://api.github.com/repos/'+REPOSITORY+path,method=method,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={'Authorization':'Bearer '+os.environ['GH_TOKEN'],'Accept':'application/vnd.github+json',
            'Content-Type':'application/json','X-GitHub-Api-Version':'2022-11-28'})
    with urllib.request.urlopen(request,timeout=40) as response:
        body=response.read();return json.loads(body) if body else None

def artifact_json(artifact,filename):
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self,*args,**kwargs): return None
    request=urllib.request.Request('https://api.github.com/repos/'+REPOSITORY+
        '/actions/artifacts/'+str(artifact['id'])+'/zip',headers={
        'Authorization':'Bearer '+os.environ['GH_TOKEN'],'Accept':'application/vnd.github+json'})
    try: response=urllib.request.build_opener(NoRedirect).open(request,timeout=40)
    except urllib.error.HTTPError as error:
        if error.code not in (301,302,303,307,308): raise
        location=error.headers['Location'];host=urllib.parse.urlsplit(location)
        if host.scheme!='https' or not (host.hostname.endswith('.blob.core.windows.net')
            or host.hostname.endswith('.githubusercontent.com')): raise RuntimeError('Unrecognized artifact host')
        response=urllib.request.urlopen(location,timeout=40)
    with response: data=response.read(8*1024*1024+1)
    if len(data)>8*1024*1024: raise RuntimeError('Unexpected evidence archive size')
    with zipfile.ZipFile(io.BytesIO(data)) as bundle:
        items=[i for i in bundle.infolist() if i.filename.split('/')[-1]==filename]
        if len(items)!=1 or items[0].file_size>65536: raise RuntimeError('Missing or oversized evidence')
        return json.loads(bundle.read(items[0]))

def validate_evidence(items,tag,build_run,digest):
    if len(items)!=2 or {i.get('api') for i in items}!={28,31}: raise RuntimeError('Both Android versions are required')
    for item in items:
        if item.get('release_tag')!=tag or item.get('source_build_run_id')!=str(build_run):
            raise RuntimeError('Evidence belongs to another release/build')
        if item.get('release_apk_sha256')!=digest: raise RuntimeError('Evidence APK digest differs')
        if any(item.get(key) is not True for key in CHECKS): raise RuntimeError('A device migration check did not pass')

def verify_build(tag,build_run):
    commit=github('/commits/'+tag)['sha'];run=github('/actions/runs/'+str(build_run))
    if run['head_sha']!=commit or run['event']!='push' or run['path']!='.github/workflows/release.yml':
        raise RuntimeError('Build artifact is not from the release tag')
    jobs=github('/actions/runs/'+str(build_run)+'/jobs?per_page=100')['jobs']
    builders=[j for j in jobs if j['name']=='build-and-release']
    if len(builders)!=1 or builders[0]['conclusion']!='success': raise RuntimeError('Release build did not pass')

def config_request(path,method='GET',payload=None,publisher=False):
    url=os.environ['SUPABASE_URL'].rstrip('/')
    parsed=urllib.parse.urlsplit(url)
    if parsed.scheme!='https' or not (parsed.hostname or '').endswith('.supabase.co') or parsed.username:
        raise RuntimeError('Invalid backend destination')
    headers={'apikey':os.environ['SUPABASE_ANON_KEY'],
        'Authorization':'Bearer '+os.environ['SUPABASE_ANON_KEY'],'Content-Type':'application/json'}
    if publisher: headers['X-Release-Token']=os.environ['SUPABASE_RELEASE_KEY']
    request=urllib.request.Request(url+path,method=method,headers=headers,
        data=json.dumps(payload).encode() if payload is not None else None)
    with urllib.request.urlopen(request,timeout=40) as response: return json.load(response)

def publish(tag,build_run,verification_run):
    verify_build(tag,build_run)
    run=github('/actions/runs/'+str(verification_run))
    if run['path']!='.github/workflows/security-recovery.yml' or run['event']!='workflow_dispatch' or run['conclusion']!='success':
        raise RuntimeError('Recovery verification workflow has not passed')
    jobs=github('/actions/runs/'+str(verification_run)+'/jobs?per_page=100')['jobs']
    devices=[j for j in jobs if j['name'].startswith('verify-signing-upgrade')]
    if len(devices)!=2 or any(j['conclusion']!='success' for j in devices): raise RuntimeError('Both device jobs must pass')
    releases=[r for r in github('/releases?per_page=30') if r['tag_name']==tag]
    if len(releases)!=1: raise RuntimeError('Expected one release')
    release=releases[0];assets=[a for a in release['assets'] if a['name']=='app-release.apk']
    if len(assets)!=1 or not re.fullmatch(r'sha256:[0-9a-f]{64}',assets[0].get('digest') or ''):
        raise RuntimeError('Release asset digest missing')
    digest=assets[0]['digest'][7:]
    artifacts=github('/actions/runs/'+str(verification_run)+'/artifacts?per_page=100')['artifacts']
    evidence=[]
    for api in (28,31):
        matches=[a for a in artifacts if a['name']==f'signing-verification-api{api}' and not a['expired']]
        if len(matches)!=1: raise RuntimeError('Device evidence artifact missing')
        evidence.append(artifact_json(matches[0],f'signing-api{api}.json'))
    validate_evidence(evidence,tag,build_run,digest)
    desired={'latest_version':tag[1:],'min_version':tag[1:],'force_update':True,
        'apk_url':'https://github.com/'+REPOSITORY+'/releases/download/'+tag+'/app-release.apk'}
    path='/rest/v1/app_config?id=eq.kroscek&select=latest_version,min_version,force_update,apk_url'
    before=config_request(path)
    if len(before)!=1: raise RuntimeError('Missing release configuration')
    if tuple(map(int,before[0]['latest_version'].split('.')))>tuple(map(int,tag[1:].split('.'))):
        raise RuntimeError('Refusing a release downgrade')
    github('/releases/'+str(release['id']),'PATCH',{'name':'KROSCEK '+tag+' - Pembaruan Keamanan',
        'draft':False,'prerelease':False,'make_latest':'true','body':
        'Pembaruan keamanan untuk Android 9 atau lebih baru.\n\n'
        '- Kunci signing pengganti dengan upgrade dan penolakan key lama yang diuji pada Android 9 dan 12.\n'
        '- Pembatasan sumber APK, koneksi jaringan, identitas, serta akses backend.\n\n'
        'Pasang app-release.apk sebagai pembaruan aplikasi lama untuk mempertahankan data.\n\n'
        'SHA-256 APK: `'+digest+'`'})
    if before[0]!=desired:
        config_request('/functions/v1/release-config','POST',{'version':tag[1:]},True)
    after=config_request(path)
    if after!=[desired]: raise RuntimeError('Release configuration verification failed')
    print(json.dumps({'published':True,'release_url':release['html_url'],'apk_sha256':digest,
        'backend_update_verified':True,'verification_run_id':verification_run}))

def main():
    tag=os.environ['RELEASE_TAG']
    if not re.fullmatch(r'v\d{1,4}\.\d{1,4}\.\d{1,4}',tag): raise RuntimeError('Invalid release tag')
    if os.environ.get('GITHUB_REPOSITORY')!=REPOSITORY: raise RuntimeError('Unexpected repository')
    build_run=number('BUILD_RUN_ID')
    if sys.argv[1]=='verify-build': verify_build(tag,build_run);print('Release build/tag association verified')
    elif sys.argv[1]=='publish': publish(tag,build_run,number('VERIFICATION_RUN_ID'))
    else: raise RuntimeError('Unknown recovery operation')

if __name__=='__main__':
    try: main()
    except urllib.error.HTTPError as error: raise SystemExit('Recovery operation failed: HTTP '+str(error.code))
    except RuntimeError as error: raise SystemExit(str(error))
