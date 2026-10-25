"""Require a successful tag build, including both Android migration checks."""
import json
import os
import re
import urllib.request
import urllib.parse

tag=os.environ['RELEASE_TAG']
if not re.fullmatch(r'v\d{1,4}\.\d{1,4}\.\d{1,4}',tag): raise SystemExit('Invalid release tag')
repository=os.environ['GITHUB_REPOSITORY']
if repository!='lemuranonim/KrosCekApps': raise SystemExit('Unexpected repository')
def read(path):
    request=urllib.request.Request('https://api.github.com/repos/'+repository+path,
        headers={'Authorization':'Bearer '+os.environ['GH_TOKEN'],
            'Accept':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28'})
    with urllib.request.urlopen(request,timeout=30) as response: return json.load(response)
head=read('/commits/'+tag)['sha']
runs=read('/actions/runs?'+urllib.parse.urlencode({'event':'push','head_sha':head,'per_page':30}))['workflow_runs']
matching=[run for run in runs if run['path']=='.github/workflows/release.yml' and run['head_branch']==tag]
if not matching or matching[0]['conclusion']!='success':
    raise SystemExit('Release withheld: the signing migration workflow has not passed')
jobs=read('/actions/runs/'+str(matching[0]['id'])+'/jobs?per_page=100')['jobs']
checks=[job for job in jobs if job['name'].startswith('verify-signing-upgrade')]
if len(checks)!=2 or any(job['conclusion']!='success' for job in checks):
    raise SystemExit('Release withheld: Android 9 and Android 12 upgrade checks must both pass')
print('Verified successful tag build and both Android signing migration checks.')
