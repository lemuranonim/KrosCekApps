"""Non-destructive live checks using only the application's public credential."""
from datetime import datetime,timezone
import json
from pathlib import Path
import re
import urllib.request
import urllib.error

ROOT=Path(__file__).resolve().parents[2]
values={k:v.strip('"\'') for k,v in re.findall(r'^(SUPABASE_URL|SUPABASE_ANON_KEY)\s*=\s*(.*?)\s*$',
    (ROOT/'.env').read_text(encoding='utf-8'),re.M)}
checks=[
    ('public release config','GET','/rest/v1/app_config?id=eq.kroscek&select=latest_version,min_version,force_update',None,{200}),
    ('anonymous profiles','GET','/rest/v1/app_users?select=id&limit=0',None,{401,403}),
    ('anonymous fields','GET','/rest/v1/master_fields?select=field_number&limit=0',None,{401,403}),
    ('anonymous audit','GET','/rest/v1/audit_harvest?select=field_number&limit=0',None,{401,403}),
    ('anonymous admin RPC','POST','/rest/v1/rpc/admin_count_master_qa_mapping',{}, {401,403,404}),
    ('anonymous QA resolver','POST','/rest/v1/rpc/resolve_unique_qa_fi',
      dict.fromkeys(['p_qa_spv','p_region','p_district_kab','p_sub_district_kec','p_village_desa','p_fa','p_field_spv'],''),{401,403,404}),
    ('retired recall','POST','/functions/v1/recall-sync-to-act',{}, {410}),
    ('anonymous ACT authorization check','POST','/functions/v1/act-master-fields-sync',{'authorizationCheck':True},{401,403}),
    ('anonymous release publisher','POST','/functions/v1/release-config',{'version':'4.9.10'},{401,403}),
]
results=[];config=None
for name,method,path,body,expected in checks:
    headers={'apikey':values['SUPABASE_ANON_KEY'],'Authorization':'Bearer '+values['SUPABASE_ANON_KEY'],
        'Content-Type':'application/json'}
    request=urllib.request.Request(values['SUPABASE_URL'].rstrip('/')+path,headers=headers,method=method,
        data=json.dumps(body).encode() if body is not None else None)
    try:
        with urllib.request.urlopen(request,timeout=30) as response:
            status=response.status
            if name=='public release config': config=json.load(response)
    except urllib.error.HTTPError as error: status=error.code
    results.append({'check':name,'status':status,'passed':status in expected})
report={'checked_at_utc':datetime.now(timezone.utc).isoformat(),'checks':results,
    'release_config':config,'business_row_mutations_attempted':False,'auth_accounts_created':False}
path=ROOT/'security_audit/2026-10-24/public_containment_verification.json'
path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
if not all(item['passed'] for item in results): raise SystemExit(1)
