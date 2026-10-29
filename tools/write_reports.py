"""Readable research index generated solely from this project's fresh analysis."""
import json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 inv=json.loads((ROOT/'research/reports/archive_inventory.json').read_text())
 lines=['# Полная инвентаризация переданного JAR','',f"SHA-256: `{inv['sha256']}`.",'','Все 88 записей, включая каталог META-INF. Назначение и статус отражают фактическое исследование. Байты оригинала не менялись.','', '| Файл | Байт | Формат / назначение | Использование | Статус |','|---|---:|---|---|---|']
 for r in inv['entries']:
  lines.append('| '+r['path']+' | '+str(r['size'])+' | '+r['format']+'; '+r['purpose']+' | '+r.get('usage','archive layout').replace('|','\\|')+' | '+r['status']+' |')
 lines+=['','Все поля размера, даты, SHA-256, PNG dimensions, sprite IDs и индексы ресурсов доступны в `research/reports/archive_inventory.json`.','', 'Тексты: старый заявленный размер 69485 байт, фактически 30158. Есть 38 неиспользуемых хвостовых байт. Они сохранены и перечислены в `anomalies.json`.']
 (ROOT/'research/INVENTORY.md').write_text('\n'.join(lines)+'\n')
 c=json.loads((ROOT/'game/data/classes.json').read_text());lines=['# Классы и методы оригинала','','Имена методов и JVM-дескрипторы сохранены. Для точной проверки используется `research/bytecode/<class>.txt`; дизассемблированы все классы.','']
 for name,v in c.items():
  lines += [f"## {name} — {next(r['purpose'] for r in inv['entries'] if r['path']==name+'.class')}",'',f"JVM {v['version']}; superclass `{v['parent']}`; {len(v['fields'])} полей, {len(v['methods'])} методов.",'','| Метод | Инструкций | Обработчиков исключений |','|---|---:|---:|']
  for key,m in v['methods'].items():lines.append(f"| `{key}` | {len(m.get('code',[]))} | {len(m.get('exceptions',[]))} |")
  lines.append('')
 (ROOT/'research/CLASS_METHOD_INDEX.md').write_text('\n'.join(lines)+'\n')
if __name__=='__main__':main()
