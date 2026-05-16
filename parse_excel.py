import pandas as pd
import json
import os

df_defects = pd.read_excel('BMS_Defects_Tables_102925.xlsx', sheet_name='SD_Defects', header=2)
df_criteria = pd.read_excel('BMS_Defects_Tables_102925.xlsx', sheet_name='SD_Criteria', header=0)

df_defects = df_defects.dropna(subset=['CODE'])

# Clean up column names just in case
df_criteria.columns = [str(c).strip() for c in df_criteria.columns]

rules = []
for _, row in df_defects.iterrows():
    code = str(row['CODE']).strip()
    if code == 'nan': continue
    
    # Get criteria for this defect (strip decimals if parsed as float)
    if code.endswith('.0'): code = code[:-2]
    
    crit_rows = df_criteria[df_criteria['Defect Code'].astype(str).str.strip().str.replace('.0', '') == code]
    
    criteria = []
    for _, c_row in crit_rows.iterrows():
        severity_str = str(c_row['Severity']).strip()
        sev_parts = severity_str.split('-')
        severity_val = sev_parts[0].strip() if len(sev_parts) > 0 else ''
        rating_val = sev_parts[-1].strip() if len(sev_parts) > 1 else ''
        
        criteria.append({
            'code': str(c_row['CODE']).strip(),
            'severity': severity_val,
            'rating': rating_val,
            'description': str(c_row['Condition Rating Criteria']).strip()
        })
        
    params = []
    for p in ['Parameter1', 'Parameter2', 'Parameter3']:
        if pd.notna(row[p]) and str(row[p]).strip() != '' and str(row[p]).strip() != 'nan':
            params.append(str(row[p]).strip())
            
    col_area = "Area Req'd?"
    area_req = False
    if col_area in row and pd.notna(row[col_area]):
        area_req = str(row[col_area]).strip().upper() == 'Y'
        
    attr_class = ""
    col_class = "Attribute Class"
    if col_class in row and pd.notna(row[col_class]):
        attr_class = str(row[col_class]).strip()

    # Get Attribute (handling potential trailing space in column name)
    attr_val = ""
    for col in row.index:
        if str(col).strip() == "Attribute":
            attr_val = str(row[col]).strip()
            break

    rules.append({
        'id': str(row['ID']).strip(),
        'code': code,
        'element': str(row['Element']).strip(),
        'attribute': attr_val,
        'material': str(row['Material']).strip(),
        'defect': str(row['Type of Damage']).strip(),
        'parameters': params,
        'requires_area': area_req,
        'attribute_class': attr_class,
        'criteria': criteria
    })

os.makedirs('assets/data', exist_ok=True)
with open('assets/data/defect_rules.json', 'w', encoding='utf-8') as f:
    json.dump(rules, f, indent=2, ensure_ascii=False)

print(f'Successfully generated defect_rules.json with {len(rules)} rules.')