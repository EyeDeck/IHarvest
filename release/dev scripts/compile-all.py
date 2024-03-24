import sys, os, subprocess, fileinput, re

dirs_to_compile = ["E:/Bethesda Softworks/MO2 SSE Mods/IHarvest/Source/Scripts"] #["C:\Program Files (x86)\Steam\SteamApps\common\Skyrim Special Edition"]
output_dir = "../../Scripts"
game_dir = "C:/Program Files (x86)/Steam/SteamApps/common/Skyrim Special Edition"
scripts_dir = game_dir + "/Data/Source/Scripts"
SkyUI_dir = "E:/Bethesda Softworks/MO2 SSE Mods/SkyUI 5.1 SDK/Source/Scripts"
compiler = game_dir + "/Papyrus Compiler/PapyrusCompiler.exe"
flags = game_dir + "/Papyrus Compiler/TESV_Papyrus_Flags.flg"
prefix = "IH_"
debugs = [("Debug.", ";~bug."), ("IH_Util.ihTrace", ";~_Util.ihTrace")]

ignore_file_time = remove_debug = enable_debug = False

if (len(sys.argv) > 1):
	print("Flags: ")
	if "-r" in sys.argv or "-release" in sys.argv:
		remove_debug = True
	if "-d" in sys.argv or "-debug" in sys.argv:
		enable_debug = True
	if "-i" in sys.argv or "-ignorefiletime" in sys.argv:
		ignore_file_time = True

	if enable_debug and remove_debug:
		print("Invalid arguments! -debug and -release flags are mutually exclusive.")
		exit()
	elif enable_debug:
		print("\t-debug: debug strings will be uncommented.")
	elif remove_debug:
		print("\t-release: debug strings will be commented out.")
	if ignore_file_time:
		print("\t-ignorefiletime: All files will be recompiled regardless of modified time")

for dir in dirs_to_compile:
	files = os.listdir(dir)
	os.chdir(dir)
	for file in files:
		print(file)
		if prefix in file and file[-4:] == ".psc":
			did_replace = False
			if remove_debug or enable_debug:
				f = open(file, 'r+')
				r_str = f.read()
				w_str = r_str
				for d in debugs:
					print(d)
					w_str = re.sub(r"(\n\s*)(" + (d[0] if remove_debug else d[1]) + ")", r"\1" + d[1] if remove_debug else d[0], w_str)
				# only bother to rewrite if the string reference changed (i.e. the replace did something)
				if (r_str != w_str):
					did_replace = True
					f.seek(0)
					f.truncate()
					f.write(w_str)
				f.close()
			if (not ignore_file_time):
				outfile = output_dir + "\\" + file[:-4] + ".pex"
				if os.path.exists(outfile) and os.path.getmtime(outfile) > os.path.getmtime(file):
					print("Skipping " + file + " (pex newer than psc)")
					continue
			args = [compiler, file, "-i=" + scripts_dir + ";" + dir + (";" + SkyUI_dir if SkyUI_dir else ""), "-o=" + output_dir, "-f=" + flags, "-q"]
			#for a in args:
			#	print(a)
			print(("Compiling " if not did_replace else "Replacing debug and compiling ") + file)
			if subprocess.call(args) != 0:
				print("Compiler error. Stopping.")
				input()
				exit()