# CSV System

This is a list of CSV files that can be used with the Outer Wilds autosplitter.<br>
These CSV files contains a list of Conditions, Signals and Facts that will become settings in the autosplitter.<br>
* For example this:<br>
`Fact; CT_CHERT_X1; Ember Twin; Chert's Camp; Talk to Chert`<br>
Will become this:<br>
![Chert.png](https://github.com/78epo/Autosplitters/blob/main/Outer%20Wilds/CSV/Images_RM/CSV_Chert.png)<br>
Now if you turn "Talk to Chert" on the autosplitter will look for the moment CT_CHERT_X1 is unlocked in the savefile, and split when it is<br>


## HOW TO USE IT?

* Find your Livesplit folder. For example `C:\Program Files\Livesplit`<br>
* Here, naviguate to the `Components` folder. This is where the autosplitter is stored<br>
* Here, create a folder named `OW`. You should now be in `C:\Program Files\Livesplit\Components\OW`<br>
* This is where the autosplitter will look for the CSV files<br>
* To download a file click on it and press **Ctrl + Shift + S**


## HOW TO CREATE YOUR OWN CSV?

* To find the values you'll put in your CSV you can complete your run once check your savefile for everything that has been unlocked<br>
*The path to your savefile will be `C:\Users\XXXX\AppData\LocalLow\Mobius Digital\Outer Wilds`. The folder will be either SteamSaves if you use Steam or Saves if you use Epic*<br>
* If you are confortable with it you can also check the github page of the mod in question and look in the code<br>
* Then you can create a basic CSV containing what you found. For example with a file named OW_Example.xxx containing:<br>
    ```
    Condition; MOD_CONDITION_X
    Signal; 70
    Fact; ERNESTO_X1
    ```
    It will look like this:<br>
    ![Example1.png](https://github.com/78epo/Autosplitters/blob/main/Outer%20Wilds/CSV/Images_RM/CSV_Example1.png)<br>
* You can click on Deactivate and then on Activate to reload your settings so that the modifications of your file appear<br>
* If you want to know exactly how each of those is unlocked you can use the setting "Options" -> "Debug - Update the name of the split..."<br>
Now everytime one of your savefile related split is activated, its name will be displayed on Livesplit<br>
<img src="https://github.com/78epo/Autosplitters/blob/main/Outer%20Wilds/CSV/Images_RM/CSV_Livesplit.png" alt="Livesplit.png" width="210"/><br>
NOTE: You can record it to be sure not to miss the moment where the split happened. The name of your splits will be overwritten, so be careful not to save over splits you care about.<br>
* Now that you know every details you can add a description, and even subdivise your splits<br>
    ```
        Condition; MOD_CONDITION_X;         Meet the condition X
        Signal; 70;                         Scan the signal of planet X
        Fact; ERNESTO_X1; Ernesto;          Talk to Ernesto
        Fact; ERNESTO_X2; Ernesto;          Ask to Ernesto how he died
        Fact; WALL_X1; Wall of knowledge;   Read the wall of knowledge
    ```
    ![Example2.png](https://github.com/78epo/Autosplitters/blob/main/Outer%20Wilds/CSV/Images_RM/CSV_Example2.png)<br>


## FORMAT RULES

* The CSV file needs to be in the `Livesplit\Components\OW` folder. The name of the file needs to start with OW_<br>
* Values are separated by a `;`
* The **first value** of a line must be either `Condition`, `Signal` or `Fact` (case sensitive). Anything else will be ignored<br>
    * Conditions are persistent progress milestones<br>
    * Signals are simply the signals you can scan<br>
    * Facts are the knowledge that end up in your shiplog, often obtained by talking or reading<br>
    * All of them are saved in your savefile<br>
* The **second value** will be the name of the Condition/Signal/Fact. Conditions and Facts have a name, Signals are a number<br>
* The **last value** will be the name displayed, ideal for a description.<br>
* Any field between the second and the last one will serve as a parent subcategory, ideal to organize long lists<br>
* You need at least two values<br>
* A line without any `;` will be ignored by the autosplitter, you can use that to comment your file if you want to<br>
