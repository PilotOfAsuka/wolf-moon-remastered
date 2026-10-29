class_name WolfSaveManager
extends RefCounted
## Original RMS records are stored byte-for-byte inside checksummed, versioned,
## atomically replaced envelopes. The original game decides when to checkpoint.
var records: Dictionary = {}
var persistent: bool = true
var directory: String = "user://records"
var last_error: String = ""

func load_all() -> void:
	if not persistent: return
	DirAccess.make_dir_recursive_absolute(directory)
	for path: String in DirAccess.get_files_at(directory):
		if not path.ends_with(".json"): continue
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory+"/"+path))
		if not doc is Dictionary or doc.get("version") != 1: continue
		var bytes: PackedByteArray = Marshalls.base64_to_raw(doc.get("payload",""))
		if bytes.hex_encode().sha256_text() != doc.get("checksum"): continue
		var arr: Array = []
		for b: int in bytes: arr.append(WolfVM.signed(b,8))
		records[doc.name] = arr

func commit(name: String, data: Array) -> bool:
	records[name] = data.duplicate()
	if not persistent: return true
	DirAccess.make_dir_recursive_absolute(directory)
	var bytes: PackedByteArray = []
	for b: Variant in data: bytes.append(int(b)&255)
	var doc: Dictionary = {"version":1,"name":name,"payload":Marshalls.raw_to_base64(bytes),"checksum":bytes.hex_encode().sha256_text()}
	var path: String = directory+"/"+name.sha256_text()+".json"
	var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: last_error = error_string(FileAccess.get_open_error()); return false
	file.store_string(JSON.stringify(doc))
	file.flush()
	file.close()
	var result: Error = DirAccess.rename_absolute(path+".tmp",path)
	last_error = error_string(result) if result != OK else ""
	return result == OK

func delete(name: String) -> void:
	records.erase(name)
	if persistent:
		var path: String = directory+"/"+name.sha256_text()+".json"
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
