//Download dbgview to see the comments.
state("OuterWilds") {}

//1.3.0 -Added full 100% splits with descriptions + support for custom settings based on CSV files
//1.2.9 -Scanning quality and mod compatibility improved + now async. onStart, onSplit, onReset implemented
//1.2.8 -Added an error message when scanning fails. Reworked the facts splits so that they work regardless of the savefile organisation
//1.2.7 -Reworked the splits to better match current usage, added death splits. Reworked scanning so that it stops searching if the target is not found
//1.2.6 -Reworked timer behaviour on the menu and added an option for categories using Menu Storage
//1.2.5 -Updated for the 1.1.13 version
//1.2.4 -Updated for the 1.1.12 version. Now Works for 1.0.7, 1.1.10, 1.1.11 & 1.1.12
//1.2.3 -Reworked 100% Splits & completed Descriptions for the Stranger's Facts + WarpCore split fix + Physics rate warning
//1.2.2 -Added 100% Splits & Signals Splits + an option to reset your savefile automatically + a lot of small stuff and fixes
//1.2.1 -Added "Free Splits" for the dlc, with the possibility to split when entering/exiting the Stranger/Ring/Dream World
//1.2.0 -Updated for the dlc, now support at least 1.0.7 & 1.1.10
//1.1.5 -Added a split for the Destroy Spacetime category & forces the timer to compare against 'Game Time'
//1.1.4 -Added an option for resetting on quit out when you haven't splitted yet
//1.1.3 -Added a split option for entering the Quantum Moon
//1.1.2 -Changed the "_firstDeath" split into 3 splits : -Loss of HP -Impact -Anglerfish
//1.1.1 -The "warp core related" splits can now be triggered again after starting a new expedition. the _exitWarp split is now triggered at the end of the warping animation
//1.1.0 -Added Splits and Options (too much to list)
//1.0.0 -Initial release

//Launched when the script first loads (so only once)
startup {
	//vars.print = (Action<dynamic>) ((output) => print("[Outer Wilds ASL] " + output));
	print("__STARTUP START__");

	if(timer.CurrentTimingMethod == TimingMethod.RealTime) {
		timer.CurrentTimingMethod = TimingMethod.GameTime;
		print("Timing Method Changed!");
	}

	vars.name = "Outer Wilds Autosplitter 1.3.0b";
	vars.ver = new string[] {"1.0.7", "1.1.10+", "1.1.12", "1.1.13+", "1.1.15"};
	vars.timer = new TimerModel { CurrentState = timer };
	vars.startupTime = DateTime.Now;
	vars.debug = false;//Skip parts of the program, useful to test things
	vars.scanFail = false;//Simulate what happens when the scans fail
	vars.factPrint = false;
	vars.init = 0;

	vars.load = false;
	vars.menu = false;
	vars.loop = 0;
	vars.warpCoreLoop = -1;

	vars.path = "";
	vars.Save = "";
	vars.writeTime = "";
	vars.frame = (float)1/60;

	vars.saveFactsList = new Dictionary<string, string> {};
	vars.saveSigCondList = new Dictionary<string, string> {};
	vars.factSplits = new List<string> {};
	vars.sigCondSplits = new List<string> {};
	vars.anythingToSplit = false;
	vars.splits = new Dictionary<string, bool>
    {
		{ "_sleep", false },
		{ "_wearSuit", false },
		{ "_firstWarp", false },
		{ "_warpCore", false },
		{ "_exitWarp", false },
		{ "_dBramble", false },
		{ "_dBrambleVessel", false },
		{ "_qMoonIn", false },
		{ "_vesselWarp", false }
	};
	
	//Look for a specific part of the game code, in this case a variable we want, since the game code doesn't change it works better than pointer paths for this game (likely because of Unity)
	vars.signatureScan = (Func<Process, string, int, string, IntPtr>)((process, name, offset, target) => {
		print("____________\n" + name + " attempt\n____________");
		IntPtr ptr = IntPtr.Zero;
		if (vars.scanFail)
			target += "fail";
		foreach (var page in process.MemoryPages())
		{
			var scanner = new SignatureScanner(process, page.BaseAddress, (int)page.RegionSize);
			if (ptr == IntPtr.Zero)
			{
				ptr= scanner.Scan(new SigScanTarget(offset,target));
			}
			if (ptr != IntPtr.Zero) {
				print("---------------------------------\n" + name + " address found at : 0x" + ptr.ToString("X8") + "\n---------------------------------");
				break;
			}
		}
		return(ptr);
	});

	//Compare multiple variable used to load a new scene to detect if the scene we want is loading in the situation we want
	vars.loadCompare = (Func<int, int, int, int, bool, bool>)((loadingSceneOld, loadingSceneCurrent, currentScene, fadeType, asyncTransition) => {
		if(loadingSceneOld==vars.scene.Old && loadingSceneCurrent==vars.scene.Current)
			return((currentScene==vars.sceneC.Current || currentScene==-1) && fadeType==vars.fadeT.Current && asyncTransition==vars.allowAsync.Current);
		return(false);
	});
	
	//2 functions in one
	vars.createSetting = (Action<string, string, string, bool>)((name, description, tooltip, enabled) => {
		try {
			//print("CS = " + name);
			settings.Add(name, enabled, description);
			settings.SetToolTip(name, tooltip);
		} catch (Exception e) {
			if (e.Message.StartsWith("Parent")) {/////We can remove one of the ifs and so on
				print(e.Message);
			} else if (e.Message.StartsWith("Setting")) {//Setting 'XXXX' was already added 
				//print(e.Message);
			} else {
				print("Setting " + name + " already exists\nMessage = " + e.Message);
			}
		}
	});

	//-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
	vars.readFilename = (Func<string, string>)((path) => {
		string filename = "";
		try {
			filename = Path.GetFileNameWithoutExtension(path).Substring("OW_".Length).Replace('_', ' ');
		}
		catch (IOException e) {
			print("Error: " + e);
		}
		return filename;
	});
	/*
	vars.printCSV = (Action<List<string[]>>)((list) => {
		string str = "";
		str += "[";
		foreach (string[] row in list) {
			//print(String.Join(" ", row));
			str += "[";
			foreach (string cell in row) {
				//print(cell);
				str += cell.ToString();
				str += ", ";
			}
			str += "],\n";
		}
		str += "]\n";
		print(str);
	});
	*/
	vars.parseCSV = (Func<string[], List<string[]>>)((text) => {
		List<string[]> list = new List<string[]>();
		foreach (string line in text) {
			string[] row = line.Split(';')
					.Select(s => s.Trim())
					.Where(s => !string.IsNullOrEmpty(s))
					.ToArray();
			list.Add(row);
		}
		return (list);
	});

	vars.createSettingsCSV = (Action<List<string[]>, string>)((list, name) => {//messy
		settings.CurrentDefaultParent = null;
		string settingName = "csv_" + name;
		vars.createSetting(settingName, name, "Read from the savefile - Settings are saved at the beginning of the run, restart your run if you want to change them", false);
		settings.CurrentDefaultParent = settingName;
		if (list.Any(array => array.Length > 0 && array[0] == "Fact"))
			vars.createSetting(settingName + "_Fact", "Facts", "", false);
		if (list.Any(array => array.Length > 0 && array[0] == "Signal"))
			vars.createSetting(settingName + "_Signal", "Signals", "", false );
		if (list.Any(array => array.Length > 0 && array[0] == "Condition"))
			vars.createSetting(settingName + "_Condition", "Conditions", "", false);
		string settingCategory = "";
		foreach(string[] line in list) {
			if (line.Length < 2)
				continue;
			if (line[0] == "Condition" || line[0] == "Signal" || line[0] == "Fact") {
				settingName = "csv_" + name + "_" + line[0];
				settingCategory = line[0];
			} else {
				continue;
			}
			settings.CurrentDefaultParent = settingName;
			string actualSettingName = settingName + "_" + line[1];
			for (int i = Math.Min(2, line.Length - 1); i < line.Length; i++) {
				if (i != line.Length - 1) {
					settingName = settingName + "_" + line[i];
					vars.createSetting(settingName, line[i], "", false);
					settings.CurrentDefaultParent = settingName;
				} else {
					if (line[0] == "Fact") {
						while (vars.saveFactsList.ContainsKey(actualSettingName))
							actualSettingName += "_";
						vars.createSetting(actualSettingName, line[i], settingCategory + " - " + line[1], false);
						vars.saveFactsList.Add(actualSettingName, line[1]);
					} else {
						while (vars.saveSigCondList.ContainsKey(actualSettingName))
							actualSettingName += "_";
						vars.createSetting(actualSettingName, line[i], settingCategory + " - " + line[1], false);
						vars.saveSigCondList.Add(actualSettingName, line[1]);
					}
				}
				continue;
			}
		}
	});

	vars.handleCSV = (Action<string>)((pathname) => {
		try {
		string[] CSVText = File.ReadAllText(pathname).Split(new[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);
		List<string[]> CSV = vars.parseCSV(CSVText);
		string filename = vars.readFilename(pathname);
		vars.createSettingsCSV(CSV, filename);
		} catch (IOException e) {
			print("Error while handling " + pathname + " Error:\n" + e);
		}
	});
	//-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-


	settings.CurrentDefaultParent = null;
	vars.createSetting("GeneralOptions", "Options", "", true);
	vars.createSetting("GeneralSplits", "Splits", "Choose where you want the game to split", true);
	//vars.createSetting("DLCSplits", "100% Splits", "Choose where you want the game to split, but only if you are on version 1.1.10 or later", false);
	
	settings.CurrentDefaultParent = "GeneralOptions";
		//vars.createSetting("_menuPauseOff", "Disable the time pause on the menu (Menu Storage)", "", false);
		vars.createSetting("_menuSplit", "Split when quitting back to the menu", "", false);
		vars.createSetting("_menuReset", "Reset the timer when quitting back to the menu", "", false);
		vars.createSetting("_menuResetLite", "  ˪ Same but ONLY if you do before splitting", "", true);
		vars.createSetting("_saveFile", "Auto delete progression while keeping Launch Codes /!\\ OVERWRITE SAVEFILE", "Automatically overwrite your savefile when the timer isn't running to erase everything except the launch codes.\nYOU NEED TO RESET THE TIMER BEFORE QUITTING OUT!\nUse it by clicking \"Resume expedition\"", false);
		vars.createSetting("_factPrint", "Debug - Update the name of the split on Livesplit when it's triggered by a change in the savefile", "Useful to build your own splits for mods - check website for more info", false);/////
		vars.createSetting("_forceVersion", "Force the autosplitter to run for a specific game version", "The game need to be restarted\nBe careful, if you select the wrong version it could break the autosplitter", false);
			settings.CurrentDefaultParent = "_forceVersion";
			foreach (string item in vars.ver) {
				vars.createSetting("_v" + item, "" + item, "", false);
			}
	settings.CurrentDefaultParent = "GeneralSplits";
		vars.createSetting("_sleep", "Sleep", "", true);
		vars.createSetting("_wearSuit", "Wear spacesuit", "", false);
		vars.createSetting("_firstWarp", "Enter the ATP (Use a warp pad)", "Use any warp pad in the Solar System", false);
		vars.createSetting("_warpCore", "Grab the warp core", "", false);
		vars.createSetting("_exitWarp", "Exit the ATP", "Use any warp pad while holding the warp core", true);
		vars.createSetting("_dBramble", "Enter Dark Bramble", "", false);
		vars.createSetting("_dBrambleVessel", "Enter the vessel node in Dark Bramble", "", true);
		vars.createSetting("_qMoonIn", "Enter the Quantum Moon", "", false);
		vars.createSetting("_vesselWarp", "Warp to the Eye", "", true);
		vars.createSetting("EyeSplits", "Eye Splits", "", true);
		vars.createSetting("_bigBang", "Big Bang", "Last split of most categories, can be kept on all the time", true);
		vars.createSetting("_dst", "Destroy Spacetime", "Last split of the Destroy Spacetime category", true);
		vars.createSetting("DeathSplits", "Death Splits", "", false);
		vars.createSetting("FreeSplits", "General DLC Splits", "", false);
			settings.CurrentDefaultParent = "EyeSplits";
			vars.createSetting("_eyeSurface", "Warp to the Eye's surface", "", false);
			vars.createSetting("_eyeTunnel", "Enter the tunnel", "", false);
			vars.createSetting("_eyeObservatory", "Reach the observatory", "", false);
			vars.createSetting("_eyeMap", "Observe the map in the observatory", "", true);
			vars.createSetting("_eyeInstruments", "Start the 'Instrument Hunt' / Reach the campfire", "", true);
			settings.CurrentDefaultParent = "DeathSplits";
			vars.createSetting("_deathHP", "Death from HP loss (campfire, ghost matter, etc...)", "", false);
			vars.createSetting("_deathImpact", "Death from Impact", "", false);
			vars.createSetting("_deathOxygen", "Death from Oxygen deprivation (air or water)", "", false);
			vars.createSetting("_deathSun", "Death from the Sun", "", false);
			vars.createSetting("_deathSupernova", "Death from the Supernova", "", false);
			vars.createSetting("_deathFish", "Death from an Anglerfish", "", false);
			vars.createSetting("_deathCrushed", "Death from being Crushed (rising sand)", "", false);
			vars.createSetting("_deathElevator", "Death from an elevator", "", false);
			vars.createSetting("_deathLava", "Death from Lava (hollow's lantern)", "", false);
			vars.createSetting("_deathDream", "Die in a Dream after dying in real life", "", false);
			vars.createSetting("_deathDreamExplosion", "Die from the explosion caused by a faulty artifact", "", false);
			vars.createSetting("_deathBlackHole", "Enter the Black Hole in the ATP", "", false);
			vars.createSetting("_deathMeditation", "End a loop by meditating", "", false);
			vars.createSetting("_deathTimeLoop", "Let a loop end by itself", "", false);
			settings.CurrentDefaultParent = "FreeSplits";
			vars.createSetting("_dlc0CloakEnter", "Enter the Stranger Cloak", "", false);
			vars.createSetting("_dlc0CloakExit", "Exit the Stranger Cloak", "", false);
			vars.createSetting("_dlc0RingEnter", "Enter the Ring World", "", false);
			vars.createSetting("_dlc0RingExit", "Exit the Ring World", "", false);
			vars.createSetting("_dlc0DreamEnter", "Enter the Dream World", "", false);
			vars.createSetting("_dlc0DreamExit", "Exit the Dream World", "", false);
			for (int i = 0; i < 2; i++) {
				settings.CurrentDefaultParent = "_dlc0" + (i == 0 ? "DreamEnter" : "DreamExit");
				vars.createSetting("_dlc0" + (i == 0 ? "DreamEnter" : "DreamExit") + "Any", "Any", "", false);
				vars.createSetting("_dlc0" + (i == 0 ? "DreamEnter" : "DreamExit") + "Zone1", "Shrouded Woodlands | River Lowlands", "", false);
				vars.createSetting("_dlc0" + (i == 0 ? "DreamEnter" : "DreamExit") + "Zone2", "Starlit Cove                 | Cinder Isles", "", false);
				vars.createSetting("_dlc0" + (i == 0 ? "DreamEnter" : "DreamExit") + "Zone3", "Endless Canyon          | Hidden Gorge", "", false);
				vars.createSetting("_dlc0" + (i == 0 ? "DreamEnter" : "DreamExit") + "Zone4", "Subterranean Lake     | Submerged Structure", "", false);
			}

	//-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-

	try {
		vars.saveFile = File.ReadAllText(@"Components\data.owsave");
	} catch (IOException e) {
		vars.saveFile = "";
		print("Components\\data.owsave wasn't found. ERROR:\n" + e);
	}
	//Starting CSV settings creation
	vars.handleCSV(@"Components\OW_Shiplog.CSV");
	string directoryPath = @"Components\OW";
	if (Directory.Exists(directoryPath))
	{
		print("Directory exists");
		string[] files = Directory.GetFiles(directoryPath);
		foreach (string file in files)
		{
			print("Iterating over file = " + file);
			if (Path.GetFileName(file).StartsWith("OW_", StringComparison.OrdinalIgnoreCase)) {
				vars.handleCSV(file);
			}
		}
	}
	else
	{
		print("Directory Components/OW/ does not exist.");
	}
	//-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-
	print("__STARTUP END__ ");

	//For the splits triggered by the savefile's content
	//It's a function because on top of running in the main loop it needs to be called when the we start the timer. That way we can go over everything that has already been unlocked and make sure that we don't split for them later
	vars.splitfunc = (Func<bool, bool>)((performSplit) => {
		print("NEW SAVE");
		vars.writeTime = System.IO.File.GetLastWriteTime(vars.path);
		var fileArray = new string[] { };
		try {
			fileArray = System.IO.File.ReadAllText(vars.path).Split('\"');
		}
		catch (IOException e) {
			print("Couldn't access the file in split");
			return false;
		}
		for (int i = vars.factSplits.Count - 1; i >= 0; i--) {
			string str = vars.factSplits[i];
			int index = Array.IndexOf(fileArray, str);
			//print("Testing for str = " + str + "	" + index + "	|	" + fileArray[index + 7]);
			if (index == -1) {
				continue;
			} else {
				if (fileArray[index + 7] != ":-1,") {
					print("SPLITING FACT: " + str);
					vars.factSplits.Remove(str);
					if (performSplit) {
						if (vars.factPrint)
							timer.CurrentSplit.Name = str + " - Fact";
						vars.timer.Split();
					}
				}
			}
		}
		for (int i = vars.sigCondSplits.Count - 1; i >= 0; i--) {
			string str = vars.sigCondSplits[i];
			int index = Array.IndexOf(fileArray, str);
			if (index == -1) {
				continue;
			} else {
				if (fileArray[index + 1] == ":true,") {
					print("SPLITING SIGNAL/CONDITION: " + str);
					vars.sigCondSplits.Remove(str);
					if (performSplit) {
						if (vars.factPrint)
							timer.CurrentSplit.Name = str + ( str.All(char.IsDigit) ? "- Signal" : " - Condition" );
						vars.timer.Split();
					}
				}
			}
		}
		return true;
	});
}

//Launched whenever a game process has been found (potentially multiple times, when the game is restarted for example)
init {
	print("__INIT START__");
	vars.init = 1;
	refreshRate = 60;
	// MD5 code by CptBrian.
    string MD5Hash;
    using (var md5 = System.Security.Cryptography.MD5.Create())
        using (var s = File.Open(modules.First().FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            MD5Hash = md5.ComputeHash(s).Select(x => x.ToString("X2")).Aggregate((a, b) => a + b);
	print("HASH = " + MD5Hash);

	//Steam 1.0.7  		CFF646D642E49E06FBE02DACAA7747E0
	//Epic  1.0.7  		D2EBA93197CB5DBAAF23748E3657352F
	//Steam 1.1.10 		8AC2F7475D483025CF94EF3027A58CE7
	//Epic  1.1.10 		AD7A9F942E657193C8124B1FE0A89CB5
	//Steam 1.1.11 		C10C6961017C813F611D5D02710B07A9
	//Steam 1.1.11new	2DEA3DB5FAC0A7DF634ADEA81123561C
	//Epic  1.1.11 		AD7A9F942E657193C8124B1FE0A89CB5 (?)
	//Steam	1.1.12 		75425F7225EC5C685EC183E9E2FEFC68
	//Steam 1.1.12alt	8D09BEF112436A190C1464D82E35F119
	//Epic	1.1.12 		B56866911AECACA1488891A8A32C9BEE
	//Steam 1.1.13		7D64EC17914879EB2541002E4105C1F7
	//Epic  1.1.13		24FEAE80D912656ACA721E7729D03554
	//Steam 1.1.13alt	6F588ABC1E5E91668DE657CFB86FA169
	//Steam 1.1.14		5FFEDBC8FB33E5CE47CC9D6DE40E4A08
	//Epic  1.1.14.768	24FEAE80D912656ACA721E7729D03554 (?)
	//Steam 1.1.15.1018	F31F5C33D045B8A3F2975702D3B77CAF
	//Epic	1.1.15		24FEAE80D912656ACA721E7729D03554 (?)

	if (MD5Hash == "CFF646D642E49E06FBE02DACAA7747E0" || MD5Hash == "D2EBA93197CB5DBAAF23748E3657352F")
		version = vars.ver[0];
	else if (MD5Hash == "8AC2F7475D483025CF94EF3027A58CE7" || MD5Hash == "AD7A9F942E657193C8124B1FE0A89CB5" || MD5Hash == "C10C6961017C813F611D5D02710B07A9" || MD5Hash == "2DEA3DB5FAC0A7DF634ADEA81123561C")
		version = vars.ver[1];
	else if (MD5Hash == "75425F7225EC5C685EC183E9E2FEFC68" || MD5Hash == "B56866911AECACA1488891A8A32C9BEE" || MD5Hash == "8D09BEF112436A190C1464D82E35F119")
		version = vars.ver[2];
	else if (MD5Hash == "5FFEDBC8FB33E5CE47CC9D6DE40E4A08" || MD5Hash == "6F588ABC1E5E91668DE657CFB86FA169" || MD5Hash == "7D64EC17914879EB2541002E4105C1F7")
		version = vars.ver[3];
    else if (MD5Hash == "24FEAE80D912656ACA721E7729D03554" || MD5Hash == "F31F5C33D045B8A3F2975702D3B77CAF")
        version = vars.ver[4];
	else
		version = "unknown";

    print("Game version = " + version);
	if (settings["_forceVersion"]) {
		foreach (var item in vars.ver) {
			if(settings["_v" + item]) {
				version = item;
				print("Forced the game version to " + version);
			}
		}
	}
	vars.factPrint = settings["_factPrint"] ? true : false;

	vars.CancelSource = new CancellationTokenSource();
	//If this is true then it means that the game was launched after Livesplit, so we can give more time to the scanning process
	vars.scanningTime = ((DateTime.Now - vars.startupTime).TotalSeconds > 2) ? 50 : 25;

	//Here to access version
	vars.scanAttempts = (Func<Process, string, int[], string[], string[], IntPtr>)((process, name, offset, target, ver) => {
		IntPtr ptr = IntPtr.Zero;
		int l = offset.Length;
		if (l == target.Length && l == ver.Length) {
			DateTime ScanTime = DateTime.Now;
			while ((DateTime.Now - ScanTime).TotalSeconds < vars.scanningTime) {
				for (int n = 0; n < l; n++) {
					if (ver[n] == "default" || ver[n] == version || version == "unknown") {
						ptr = vars.signatureScan(process, name + " (version : " + ver[n] + ")", offset[n], target[n]);
						if (ptr != IntPtr.Zero) {
							if (version == "unknown") {
								version = (ver[n] == "default" ? vars.ver[vars.ver.Length - 1] : ver[n]);
								print("Version changed to " + version);
							}
							return (ptr);
						}
					}
				}
				if (vars.CancelSource.Token.IsCancellationRequested) {
					print("Task " + name + " cancelled\n");
					return (ptr);
				}
				System.Threading.Thread.Sleep(80 * vars.scanningTime);//2000 or 4000
			}
			vars.scanningErrors.Add(name);
			print("Scanning failed: " + name);
		}
		return (ptr);
	});

	IntPtr ptrLocator = IntPtr.Zero;
	IntPtr ptrTime = IntPtr.Zero;
	IntPtr ptrLoad = IntPtr.Zero;
	IntPtr ptrProfile = IntPtr.Zero;
	
	vars.scanningErrors = new List<string> {};

	System.Threading.Tasks.Task taskLocator = System.Threading.Tasks.Task.Run(async () =>
	{
		int[] offsetArray = new int[] {43, 49};
		string[] targetArray = new string[] {
							"0F84 ???????? 41 83 3F 00 49 BA ???????????????? 49 8B CF 66 90 49 BB ???????????????? 41 FF D3 48 8B C8 48 B8",
							"0F84 ???????? 41 83 3F 00 49 BA ???????????????? 49 8B CF 48 83 EC 20 49 BB ???????????????? 41 FF D3 48 83 C4 20 48 8B C8 48 B8"
						};
		string[] versionArray = new string[] {"default", "1.0.7"};
		ptrLocator = vars.scanAttempts(game, "LOCATOR", offsetArray, targetArray, versionArray);
	});

	System.Threading.Tasks.Task taskTime = System.Threading.Tasks.Task.Run(async () =>
	{
		int[] offsetArray = new int[] {14, 18};
		string[] targetArray = new string[] {
						"F3 0F2A C8 F3 0F5A C9 F2 0F5E C1 48 B8",
						"F3 0F5A C0 48 63 45 FC F2 0F2A C8 F2 0F5E C1 48 B8"
					};
		string[] versionArray = new string[] {"default", "1.0.7"};
		ptrTime = vars.scanAttempts(game, "OW_TIME", offsetArray, targetArray, versionArray);
	});

	System.Threading.Tasks.Task taskLoad = System.Threading.Tasks.Task.Run(async () =>
	{
		int[] offsetArray = new int[] {20, 14};
		string[] targetArray = new string[] {
						"55 48 8B EC 48 81 EC ???????? 48 89 75 F8 48 8B F1 48 B8 ???????????????? 48 8B 00 48 85 C0 75 15 48 B8",
						"55 48 8B EC 56 48 83 EC 78 48 8B F1 48 B8"
					};
		string[] versionArray = new string[] {"default", "1.0.7"};
		ptrLoad = vars.scanAttempts(game, "LOAD_MANAGER", offsetArray, targetArray, versionArray);
	});

	System.Threading.Tasks.Task taskProfile = System.Threading.Tasks.Task.Run(async () =>
	{
		if (version != "1.0.7") {
		int[] offsetArray = new int[] {10, 10};
		string[] targetArray = new string[] {//StandaloneProfileManager:get_SharedInstance
						"55 48 8b ec 48 83 ec 20 48 b8 ???????????????? 48 8b 00 48 85 c0 75 29",
						"55 48 8b ec 48 83 ec 30 48 b8 ???????????????? 48 8b 00 48 85 c0 0F 85 ???????? 48 b9 ???????????????? 48 8d 64 24 00 90 49 bb ???????????????? 41 ff d3 48 8b c8 48 b8"
					};
		string[] versionArray = new string[] {"default", "default"};//add an option for modded later, if needed
		ptrProfile = vars.scanAttempts(game, "PROFILE", offsetArray, targetArray, versionArray);
		}
	});

	System.Threading.Tasks.Task.Run(async () =>
	{
		print("Before await\n");
		System.Threading.Tasks.Task taskAll = System.Threading.Tasks.Task.WhenAll(taskLocator, taskTime, taskLoad, taskProfile);
		taskAll.Wait();
		print("After await\n");
		if (vars.CancelSource.Token.IsCancellationRequested) {
			return false;
		}

		if (vars.scanningErrors.Count > 0) {
			string errorMessage = "The autosplitter searches for specific parts of the game memory, it cannot function if it doesn't find them, which is what just happened.\n";
			errorMessage += "\n________________________\n\nLIST OF FAILED SCANS:\n\n";
			if (vars.scanningErrors.Contains("LOCATOR"))
				errorMessage += "-Locator\n";
			if (vars.scanningErrors.Contains("OW_TIME"))
				errorMessage += "-OW_time\n";
			if (vars.scanningErrors.Contains("LOAD_MANAGER"))
				errorMessage += "-Load_Manager\n";
			if (vars.scanningErrors.Contains("PROFILE"))
				errorMessage += "-Profile\n";
			if (vars.scanningErrors.Count >= 4) {
				errorMessage += "\nIn this case every scan failed, which could mean full incompatibility.\nNote that the autosplitter doesn't work on Windows 7 or below and on the Xbox Launcher version of the game for reasons beyond my control.\nSorry if this impacts you.\n" +
				"If you can't fix the issue you can run without the autosplitter, notify us of the issue you are encountering and your runs will be retimed.\n\nYou can contact me (Nepo.) on the Outer Wilds Speedrunning Server.\ndiscord.gg/pW4cqtEqUh\n";
			} else {
				errorMessage += "\nNot every scan failed, so it should be possible to fix the issue, try the suggestions listed below.\n" +
				"\nIf nothing worked, the error could be due to a recent game update or an unknown bug, please contact me (Nepo.) on the Outer Wilds Speedrunning Server.\ndiscord.gg/pW4cqtEqUh\n\n";
			}
			errorMessage += "If you think that the issue was caused by a mod, sharing the list of mods you had installed on the Mod Launcher and the list of failed scans with me could help A LOT, thank you!\n\n________________________\n" +
			"\nHERE IS WHAT YOU CAN DO:\n" +
			"\nCheck the 'Troubleshooting' part of this link to have all the details:\ngithub.com/sseneca42/Outer-Wilds-Autosplitter\n(Click on 'Website' next to 'Settings' in your splits)\n\n" +
			"· Once they have been used, mods can impact the scanning process even if they weren't launched.\nYou can verify the integrity of the game files through Steam or create a separate install of the game.\n(check Discord or the link if you need some help)\n" +
			"· Make sure that Livesplit is up to date. Try to launch Livesplit in Administrator mode or in Windows 8 compatibility mode.\n" +
			"· The scanning process runs for a set amount of time before giving up and displaying this error, if your game takes a very long time to launch try opening it before you launch Livesplit.\n\n";
			
			MessageBox.Show(
				errorMessage,
				"LiveSplit - " + vars.name + " - SCANNING ERROR",
				MessageBoxButtons.OK, MessageBoxIcon.Error
			);
		}
		if (version != "1.0.7") {
			vars.Profile = (IntPtr)(game.ReadValue<long>(ptrProfile));
			print("|\nPOINTER Profile : 0x" + vars.Profile.ToString("X8") + "\n|");
			//StandaloneProfileManager - 0x90 _currentprofile - 0x10 _profileName - 0x10 Length
			vars.nameLength = new MemoryWatcher<int>(new DeepPointer(vars.Profile, 0x90, 0x10, 0x10));
			//StandaloneProfileManager - 0x78 __profilesPath - 0x10 Length
			vars.pathLength = new MemoryWatcher<int>(new DeepPointer(vars.Profile, 0x78, 0x10));
		} else {
			vars.nameLength = new MemoryWatcher<bool>(new DeepPointer(IntPtr.Zero));
			vars.pathLength = new MemoryWatcher<bool>(new DeepPointer(IntPtr.Zero));
		}

		IntPtr Locator = (IntPtr)(game.ReadValue<long>(ptrLocator));
		print("|\nPOINTER Locator : 0x" + Locator.ToString("X8") + "\n|");

		IntPtr OW_Time = (IntPtr)(game.ReadValue<long>(ptrTime));
		print("|\nPOINTER OW_Time : 0x" + OW_Time.ToString("X8") + "\n|");

		IntPtr Load = (IntPtr)(game.ReadValue<long>(ptrLoad));
		print("|\nPOINTER LoadManager : 0x" + Load.ToString("X8") + "\n|");

		if (version != "1.0.7") {
			//LOCATOR_1_1_10+________________________________________________________________________________________________
			//Locator - 0x8 _playerController - 0x139 _isWearingSuit
			vars.isWearingSuit = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x8, 0x139));
			//Locator - 0x8 _playerController - 0x144 _inWarpField
			vars.inWarpField = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x8, 0x144));
			//---
			//Locator - 0x28 _toolModeSwapper - 0x40 _itemCarryTool - 0x98 _heldItem - 0x7C _type
			vars.heldItem = new MemoryWatcher<int>(new DeepPointer(Locator + 0x28, 0x40, 0x98, 0x7C));// 2 = WarpCore (not broken)
			//Locator - 0x28 _toolModeSwapper - 0x40 _itemCarryTool - 0xC0 _promptState
			vars.promptItem = new MemoryWatcher<int>(new DeepPointer(Locator + 0x28, 0x40, 0xC0));
			//---
			//Locator - 0xB8 _playerSectorDetector - 0x54 _inBrambleDimension
			vars.inBrambleDimension = new MemoryWatcher<bool>(new DeepPointer(Locator + 0xB8, 0x54));
			//Locator - 0xB8 _playerSectorDetector - 0x55 _inVesselDimension
			vars.inVesselDimension = new MemoryWatcher<bool>(new DeepPointer(Locator + 0xB8, 0x55));
			if (version == "1.1.13+" || version == "1.1.15") {
				//Locator - 0xD0 _audioMixer - 0xD2 _isSleepingAtCampfire
				vars.isSleepingAtCampfire = new MemoryWatcher<bool>(new DeepPointer(Locator + 0xD0, 0xD2));
				//---
				//Locator - 0x150 _eyeStateManager - 0x1C _state
				vars.eyeState = new MemoryWatcher<int>(new DeepPointer(Locator + 0x150, 0x1C));
				//Locator - 0x150 _eyeStateManager - 0x20 _initialized
				vars.eyeInitialized = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x150, 0x20));
				//---
				//Locator - 0x158 _timelineObliterationController - 0x40 _cameraEffect - 0x145 _isRealityShatterEffectComplete
				vars.isRealityShatterEffectComplete = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x158, 0x40, 0x145));
				//---
				//Locator - 0x230 _quantumMoon - 0x15C _isPlayerInside
				vars.inQuantumMoon = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x230 + (version == "1.1.15" ? 0x8 : 0x0), 0x15C));//0x238 instead of 0x230 in 1.1.15
			} else {
				//Locator - 0xD0 _audioMixer - 0xCA _isSleepingAtCampfire
				vars.isSleepingAtCampfire = new MemoryWatcher<bool>(new DeepPointer(Locator + 0xD0, 0xCA));
				//---
				//Locator - 0x158 _eyeStateManager - 0x1C _state
				vars.eyeState = new MemoryWatcher<int>(new DeepPointer(Locator + 0x158, 0x1C));
				//Locator - 0x158 _eyeStateManager - 0x20 _initialized
				vars.eyeInitialized = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x158, 0x20));
				//---
				//Locator - 0x160 _timelineObliterationController - 0x40 _cameraEffect - 0x145 _isRealityShatterEffectComplete
				vars.isRealityShatterEffectComplete = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x160, 0x40, 0x145));
				//---
				//Locator - 0x228 _quantumMoon - 0x15C _isPlayerInside
				vars.inQuantumMoon = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x228, 0x15C));
			}
			//Locator - 0xE0 _deathManager - 0x20 _isDying
			vars.isDying = new MemoryWatcher<bool>(new DeepPointer(Locator + 0xE0, 0x20));//0x21 for _isDead
			//Locator - 0xE0 _deathManager - 0x2c _deathType
			vars.deathType = new MemoryWatcher<int>(new DeepPointer(Locator + 0xE0, 0x2C));//6 = BigBang
			//DLC
			//---
			//Locator - 0x190 _cloakFieldController - 0x10F _playerInsideCloak
			vars.playerInsideCloak = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x190, 0x10F));
			//---
			//Locator - 0x198 _ringWorldController - 0x184 _playerInsideRingWorld
			vars.playerInsideRingWorld = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x198, 0x184));
			if (version == "1.1.10+") {
				//DreamWorldController_1_1_10/1_1_11
				//Locator - 0x1A0 _dreamWorldController - 0x131 _exitingDream
				vars.exitingDream = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x1A0, 0x131));
				//Locator - 0x1A0 _dreamWorldController - 0x133 _insideDream
				vars.insideDream = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x1A0, 0x133));
				//Locator - 0x1A0 _dreamWorldController - 0xA0 _dreamArrivalPoint - 0x48 DreamArrivalPoint.Location
				vars.dreamLocation = new MemoryWatcher<int>(new DeepPointer(Locator + 0x1A0, 0xA0, 0x48));
			} else {
				//DreamWorldController_1_1_12
				//Locator - 0x1A0 _dreamWorldController - 0x149 _exitingDream
				vars.exitingDream = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x1A0, 0x149));
				//Locator - 0x1A0 _dreamWorldController - 0x14B _insideDream
				vars.insideDream = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x1A0, 0x14B));
				//Locator - 0x1A0 _dreamWorldController - 0xB0 _dreamArrivalPoint - 0x48 DreamArrivalPoint.Location
				vars.dreamLocation = new MemoryWatcher<int>(new DeepPointer(Locator + 0x1A0, 0xB0, 0x48));
			}
		} else {
			//LOCATOR_1_0_7_________________________________________________________________________________________________
			//Locator - 0x8 _playerController - 0x131 _isWearingSuit
			vars.isWearingSuit = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x8, 0x131));
			//Locator - 0x8 _playerController - 0x13C _inWarpField
			vars.inWarpField = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x8, 0x13C));
			//---
			//Locator - 0x28 _toolModeSwapper - 0x40 _itemCarryTool - 0x80 _heldItem - 0x64 _type
			vars.heldItem = new MemoryWatcher<int>(new DeepPointer(Locator + 0x28, 0x40, 0x80, 0x64));// 2 = WarpCore (not broken)
			//Locator - 0x28 _toolModeSwapper - 0x40 _itemCarryTool - 0xA8 _promptState
			vars.promptItem = new MemoryWatcher<int>(new DeepPointer(Locator + 0x28, 0x40, 0xA8));
			//---
			//Locator - 0xB0 _playerSectorDetector - 0x54 _inBrambleDimension
			vars.inBrambleDimension = new MemoryWatcher<bool>(new DeepPointer(Locator + 0xB0, 0x54));
			//Locator - 0xB0 _playerSectorDetector - 0x55 _inVesselDimension
			vars.inVesselDimension = new MemoryWatcher<bool>(new DeepPointer(Locator + 0xB0, 0x55));
			//---
			//Locator - 0xC8 _audioMixer - 0xA0 _isSleepingAtCampfire
			vars.isSleepingAtCampfire = new MemoryWatcher<bool>(new DeepPointer(Locator + 0xC8, 0xA0));
			//---
			//Locator - 0xD8 _deathManager - 0x18 _isDying
			vars.isDying = new MemoryWatcher<bool>(new DeepPointer(Locator + 0xD8, 0x18));//0x19 for _isDead
			//Locator - 0xD8 _deathManager - 0x24 _deathType
			vars.deathType = new MemoryWatcher<int>(new DeepPointer(Locator + 0xD8, 0x24));//6 = BigBang
			//---
			//Locator - 0x148 _eyeStateManager - 0x1C
			vars.eyeState = new MemoryWatcher<int>(new DeepPointer(Locator + 0x148, 0x1C));
			//Locator - 0x148 _eyeStateManager - 0x20
			vars.eyeInitialized = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x148, 0x20));
			//---
			//Locator - 0x150 _timelineObliterationController - 0x40 _cameraEffect - 0x131 _isRealityShatterEffectComplete
			vars.isRealityShatterEffectComplete = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x150, 0x40, 0x131));
			//---
			//Locator - 0x1C8 _quantumMoon - 0x15C _isPlayerInside
			vars.inQuantumMoon = new MemoryWatcher<bool>(new DeepPointer(Locator + 0x1C8, 0x15C));
			//
			vars.playerInsideCloak = new MemoryWatcher<bool>(new DeepPointer(IntPtr.Zero));
			vars.playerInsideRingWorld = new MemoryWatcher<bool>(new DeepPointer(IntPtr.Zero));
			vars.exitingDream = new MemoryWatcher<bool>(new DeepPointer(IntPtr.Zero));
			vars.insideDream = new MemoryWatcher<bool>(new DeepPointer(IntPtr.Zero));
			vars.dreamLocation = new MemoryWatcher<int>(new DeepPointer(IntPtr.Zero));
		}

		//OW_TIME_______________________________________________________________________________________________________
		//OW_Time 0x0 s_pauseFlags (bool[7])
		vars.pauseMenu = new MemoryWatcher<bool>(new DeepPointer(OW_Time - 0x10, 0x20));//When in the ESC Menu
		vars.pauseLoading = new MemoryWatcher<bool>(new DeepPointer(OW_Time - 0x10, 0x21));//When quitting to the menu (and other maybe)
		vars.pauseSleeping = new MemoryWatcher<bool>(new DeepPointer(OW_Time - 0x10, 0x23));//Before waking up (loop beginning)
		vars.pauseInitializing = new MemoryWatcher<bool>(new DeepPointer(OW_Time - 0x10, 0x24));//When you see the "Save icon" more or less

		//OW_Time 0x10 s_fixedTimestep
		vars.fixedTimestep = new MemoryWatcher<float>(new DeepPointer(OW_Time));

		//LOADMANAGER___________________________________________________________________________________________________
		//LoadManager - 0xc s_currentScene
		vars.sceneC = new MemoryWatcher<int>(new DeepPointer(Load - 0x2C));
		//LoadManager - 0x10 s_loadingScene
		vars.scene = new MemoryWatcher<int>(new DeepPointer(Load - 0x28));
		//LoadManager - 0x24 s_fadeType
		vars.fadeT = new MemoryWatcher<int>(new DeepPointer(Load - 0x14));
		//LoadManager - 0x20 s_allowAsyncTransition
		vars.allowAsync = new MemoryWatcher<bool>(new DeepPointer(Load - 0x18));

		vars.watchers = new MemoryWatcherList() {
			vars.pauseMenu, vars.pauseLoading, vars.pauseSleeping, vars.pauseInitializing,
			vars.fixedTimestep,
			vars.sceneC, vars.scene, vars.fadeT, vars.allowAsync,
			vars.isWearingSuit,
			vars.inWarpField, vars.heldItem, vars.promptItem,
			vars.inBrambleDimension, vars.inVesselDimension,
			vars.inQuantumMoon,
			vars.eyeState, vars.eyeInitialized,
			vars.isSleepingAtCampfire,
			vars.isDying, vars.deathType,
			vars.isRealityShatterEffectComplete,
			vars.playerInsideCloak, vars.playerInsideRingWorld,
			vars.insideDream, vars.exitingDream, vars.dreamLocation,
			vars.nameLength, vars.pathLength
		};
		vars.watchers.UpdateAll(game);
		if (vars.fixedTimestep.Current != vars.frame)
			print("TIMESTEP");
		if (vars.fixedTimestep.Current < vars.frame && vars.fixedTimestep.Current != 0) {
			print("Timestep is " + vars.fixedTimestep.Current + " o " + vars.fixedTimestep.Old);
			MessageBox.Show(
				"The physics rate of the game seems to have been modified, please use the default settings (60 fps) when running.\n\n"+
				"See https://www.mobiusdigitalgames.com/supportforum.html or ask on Discord",
				"LiveSplit | " + vars.name,
				MessageBoxButtons.OK, MessageBoxIcon.Warning
			);
		}
		vars.init = 2;
		print("__INIT END__");
		print("\n~Running " + vars.name + "~\n");
		//print("DEBUG/ERROR MODE\n~NOT Running " + vars.name + "~\n");
		return true;
	});
}

//Launched when the game process is exited
exit {
	print("__EXITING THE GAME__\n");
	if (vars.init == 1)
		vars.CancelSource.Cancel();
	vars.init = 0;
	vars.path = "";
	vars.anythingToSplit = false;
	timer.IsGameTimePaused = true;//Minor issue: Never set back to false, doesn't matter but should look into it
}

shutdown {
	print("__SHUTDOWN__\n");
	if (vars.init == 1)
		vars.CancelSource.Cancel();
}

//Run in a loop after INIT. If the timer isn't running, is followed by START. If the timer is running, is followed by ISLOADING, RESET and SPLITS.
update {
	if (vars.init < 2 || vars.debug)
		return false;

	vars.watchers.UpdateAll(game);

	if(version != "1.0.7") {
		if ((vars.nameLength.Current != vars.nameLength.Old || String.IsNullOrEmpty(vars.path)) && vars.pathLength.Current != 0) {
			print("PARSE PATH BEGINNING");
			string name = "";
			vars.path = "";
			char[] str = new char[vars.nameLength.Current];
			for (int i = 0; i < vars.nameLength.Current; i++) {
				vars.tmp = new MemoryWatcher<char>(new DeepPointer(vars.Profile, 0x90, 0x10, 0x14 + (0x2 * i)));
				vars.tmp.Update(game);
				str[i] = vars.tmp.Current;
				name = new string(str);
			}
			str = new char[vars.pathLength.Current];
			for (int i = 0; i < vars.pathLength.Current; i++) {
				vars.tmp = new MemoryWatcher<char>(new DeepPointer(vars.Profile, 0x78, 0x14 + (0x2 * i)));
				vars.tmp.Update(game);
				str[i] = vars.tmp.Current;
				vars.path = new string(str);
			} 
			vars.path += "/" + name + "/data.owsave";
			vars.writeTime = System.IO.File.GetLastWriteTime(vars.path);
			print("\nPATH = " + vars.path + "\nWrite Time = " + vars.writeTime + "\n");
		}
	}

	if(vars.pauseInitializing.Old && !vars.pauseInitializing.Current)
		vars.load = false;
	if (!vars.menu && vars.loadCompare(0, 1, -1, 1, true))
		vars.menu = true;
	else if(vars.menu && ((vars.pauseSleeping.Old && !vars.pauseSleeping.Current) || (vars.loadCompare(3, 0, 3, 1, true)))) {
		vars.menu = false;
		vars.loop++;
	}
	else if(vars.loadCompare(2, 0, 2, 0, true) || vars.loadCompare(0, 3, 2, 2, false))
		vars.load = !vars.menu;
	else if( vars.loadCompare(0, 2, 1, 1, false) ||  vars.loadCompare(0, 3, 1, 1, true ) )
		vars.load = true;
}

onStart {
	print("ON START\n");
	if (vars.init == 2) {
		vars.sigCondSplits = new List<string> {};
		foreach (KeyValuePair<string, string> kvp in vars.saveSigCondList) {
			if (settings[kvp.Key]) {
				if (!vars.sigCondSplits.Contains(kvp.Value)) {
					vars.sigCondSplits.Add(kvp.Value);
				}
			}
		}
		vars.factSplits = new List<string> {};
		foreach (KeyValuePair<string, string> kvp in vars.saveFactsList) {
			if (settings[kvp.Key]) {
				if (!vars.factSplits.Contains(kvp.Value)) {
					vars.factSplits.Add(kvp.Value);
				}
			}
		}
		vars.anythingToSplit = (vars.factSplits.Count > 0 || vars.sigCondSplits.Count > 0) ? true : false;
		vars.splitfunc(false);
		string listsplit = "";
		foreach (string str in vars.factSplits) {
			listsplit += str + "\n";
		}
		print("MY FACTS SPLITS:\n" + listsplit);
		listsplit = "";
		foreach (string str in vars.sigCondSplits) {
			listsplit += str + "\n";
		}
		print("MY SIG-COND SPLITS:\n" + listsplit);
	}
}

onSplit {
	print("ON SPLIT\n");
}

onReset {
	print("ON RESET\n");
	if (vars.init == 2) {
		print("Cleaning 'Splits' Array\n");
		vars.load = false;
		vars.menu = false;
		vars.splits["_sleep"] = false;
		vars.splits["_wearSuit"] = false;
		vars.splits["_firstWarp"] = false;
		vars.splits["_exitWarp"] = false;
		vars.splits["_warpCore"] = false;
		vars.splits["_dBramble"] = false;
		vars.splits["_dBrambleVessel"] = false;
		vars.splits["_qMoonIn"] = false;
		vars.splits["_vesselWarp"] = false;
		vars.loop = 0;
		vars.warpCoreLoop = -1;
		vars.anythingToSplit = false;
	}
}

//Start the timer if it returns TRUE
start {
	if (vars.init < 2)
		return false;
	if (settings["_saveFile"] && !String.IsNullOrEmpty(vars.path) && !(vars.pauseSleeping.Current || vars.pauseInitializing.Current)) {
		try {
			if (System.IO.File.ReadAllText(vars.path) != vars.saveFile) {
				System.IO.File.WriteAllText(@vars.path, vars.saveFile);
				print("Overwriting file");
			}
		}
		catch (IOException e) {
			print("Couldn't access the file 1");
		}
	}
	if ((vars.pauseSleeping.Old && !vars.pauseSleeping.Current) || vars.loadCompare(0, 3, 1, 1, true)) {//Minor issue: starts when closing the game while on the wake up prompt 
		return true;
	}
}

//'Pause' the timer if it returns TRUE
isLoading {
	if (vars.init < 2)
		return false;
	return(vars.load || vars.menu || (vars.isSleepingAtCampfire.Current && !vars.exitingDream.Current));
}


//Reset the timer if it returns TRUE
reset {
	if (vars.init < 2)
		return false;
	return (( (settings["_menuReset"] && !settings["_menuResetLite"]) || (settings["_menuResetLite"] && timer.CurrentSplitIndex == 0)) && vars.menu);
}

//Split if it returns TRUE
split {
	if (vars.init < 2)
		return false;
	if (settings["_menuSplit"] && vars.loadCompare(0, 1, -1, 1, true))
		return true;
	if(settings["GeneralSplits"]) {
		if (vars.isDying.Current && !vars.isDying.Old) {
			print("Death type = " + vars.deathType.Current);
		}
		if (settings["_bigBang"] && vars.deathType.Current == 6 && vars.deathType.Old != 6)
			return true;
		else if (settings["_dst"] && vars.isRealityShatterEffectComplete.Current && !vars.isRealityShatterEffectComplete.Old)
			return true;
		else if (settings["_deathHP"] && vars.isDying.Current && !vars.isDying.Old && vars.deathType.Current == 0)
			return true;
		else if (settings["_deathImpact"] && vars.deathType.Old != 1 && vars.deathType.Current == 1)
			return true;
		else if (settings["_deathOxygen"] && vars.deathType.Old != 2 && vars.deathType.Current == 2)
			return true;
		else if (settings["_deathSun"] && vars.deathType.Old != 3 && vars.deathType.Current == 3)
			return true;
		else if (settings["_deathSupernova"] && vars.deathType.Old != 4 && vars.deathType.Current == 4)
			return true;
		else if (settings["_deathFish"] && vars.deathType.Old != 5 && vars.deathType.Current == 5)
			return true;
		else if (settings["_deathCrushed"] && vars.deathType.Old != 7 && vars.deathType.Current == 7)
			return true;
		else if (settings["_deathMeditation"] && vars.deathType.Old != 8 && vars.deathType.Current == 8)
			return true;
		else if (settings["_deathTimeLoop"] && vars.deathType.Old != 9 && vars.deathType.Current == 9)
			return true;
		else if (settings["_deathLava"] && vars.deathType.Old != 10 && vars.deathType.Current == 10)
			return true;
		else if (settings["_deathBlackHole"] && vars.deathType.Old != 11 && vars.deathType.Current == 11)
			return true;
		else if (settings["_deathDream"] && vars.deathType.Old != 12 && vars.deathType.Current == 12)
			return true;
		else if (settings["_deathDreamExplosion"] && vars.deathType.Old != 13 && vars.deathType.Current == 13)
			return true;
		else if (settings["_deathElevator"] && vars.deathType.Old != 14 && vars.deathType.Current == 14)
			return true;
		else if (settings["_sleep"] && !vars.splits["_sleep"] && vars.isSleepingAtCampfire.Current && !vars.isSleepingAtCampfire.Old) {
			vars.splits["_sleep"] = true;
			return true;
		}
		else if (settings["_wearSuit"] && !vars.splits["_wearSuit"] && vars.isWearingSuit.Current && !vars.isWearingSuit.Old) {
			vars.splits["_wearSuit"] = true;
			return true;
		}
		else if (vars.inWarpField.Current && !vars.inWarpField.Old && !vars.splits["_warpCore"]) {
			vars.warpCoreLoop = vars.loop;
			if (!vars.splits["_firstWarp"]) {
				vars.splits["_firstWarp"] = true;
				return (settings["_firstWarp"]);
			}
		}
		else if (!vars.splits["_warpCore"] && ((vars.heldItem.Current == 2 && vars.promptItem.Old == 3 && vars.promptItem.Current > 3) || ((vars.heldItem.Current == 2 && vars.promptItem.Old < 4 && vars.promptItem.Current == 4))) && vars.warpCoreLoop == vars.loop) {
			vars.splits["_warpCore"] = true;
			return (settings["_warpCore"]);
		}
		else if (settings["_exitWarp"] && !vars.splits["_exitWarp"] && !vars.inWarpField.Current && vars.inWarpField.Old && vars.splits["_warpCore"] && vars.warpCoreLoop == vars.loop) {
			vars.splits["_exitWarp"] = true;
			return true;
		}
		else if (settings["_dBramble"] && !vars.splits["_dBramble"] && vars.inBrambleDimension.Current && !vars.inBrambleDimension.Old) {
			vars.splits["_dBramble"] = true;
			return true;
		}
		else if (settings["_dBrambleVessel"] && !vars.splits["_dBrambleVessel"] && vars.inVesselDimension.Current && !vars.inVesselDimension.Old) {
			vars.splits["_dBrambleVessel"] = true;
			return true;
		}
		else if (settings["_qMoonIn"] && !vars.splits["_qMoonIn"] && vars.inQuantumMoon.Current && !vars.inQuantumMoon.Old) {
			vars.splits["_qMoonIn"] = true;
			return true;
		}
		else if (settings["_vesselWarp"] && !vars.splits["_vesselWarp"] && vars.eyeInitialized.Current && !vars.eyeInitialized.Old) {
			vars.splits["_vesselWarp"] = true;
			return true;
		}
		else if (settings["EyeSplits"]) {
			if (settings["_eyeSurface"] && vars.eyeState.Current == 10 && vars.eyeState.Old != 10)
				return true;
			else if (settings["_eyeTunnel"] && vars.eyeState.Current == 20 && vars.eyeState.Old != 20)
				return true;
			else if (settings["_eyeObservatory"] && vars.eyeState.Current == 40 && vars.eyeState.Old != 40)
				return true;
			else if (settings["_eyeMap"] && vars.eyeState.Current == 50 && vars.eyeState.Old != 50)
				return true;
			else if (settings["_eyeInstruments"] && vars.eyeState.Current == 80 && vars.eyeState.Old != 80)
				return true;
		}
	}
	if (version != "1.0.7") {
		if (settings["FreeSplits"]) {
			if((settings["_dlc0CloakEnter"] && vars.playerInsideCloak.Current && !vars.playerInsideCloak.Old)
			|| (settings["_dlc0CloakExit"] && !vars.playerInsideCloak.Current && vars.playerInsideCloak.Old && !vars.isDying.Current && !vars.menu)
			|| (settings["_dlc0RingEnter"] && vars.playerInsideRingWorld.Current && !vars.playerInsideRingWorld.Old && !vars.isSleepingAtCampfire.Old)
			|| (settings["_dlc0RingExit"] && !vars.playerInsideRingWorld.Current && vars.playerInsideRingWorld.Old && !vars.insideDream.Current && !vars.menu)
			|| (settings["_dlc0DreamEnter"] && vars.insideDream.Current && !vars.insideDream.Old &&
				(settings["_dlc0DreamEnterAny"]
				|| (vars.dreamLocation.Current == 100 && settings["_dlc0DreamEnterZone1"])
				|| (vars.dreamLocation.Current == 200 && settings["_dlc0DreamEnterZone2"])
				|| (vars.dreamLocation.Current == 300 && settings["_dlc0DreamEnterZone3"])
				|| (vars.dreamLocation.Current == 400 && settings["_dlc0DreamEnterZone4"]) ))
			|| (settings["_dlc0DreamExit"] && !vars.insideDream.Current && vars.insideDream.Old && !vars.isDying.Current && !vars.menu &&
				(settings["_dlc0DreamExitAny"]
				|| (vars.dreamLocation.Old == 100 && settings["_dlc0DreamExitZone1"])
				|| (vars.dreamLocation.Old == 200 && settings["_dlc0DreamExitZone2"])
				|| (vars.dreamLocation.Old == 300 && settings["_dlc0DreamExitZone3"])
				|| (vars.dreamLocation.Old == 400 && settings["_dlc0DreamExitZone4"]) ))
			) {
				return true;
			}
		}

		if(vars.anythingToSplit) {
			if (vars.writeTime != System.IO.File.GetLastWriteTime(vars.path)) {
				vars.splitfunc(true);
			}
		}
	}
	return false;
}