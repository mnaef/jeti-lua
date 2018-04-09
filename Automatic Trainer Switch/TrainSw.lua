-- Automatic Trainer/Student Switch
--
-- vim: ai:ts=4:sw=4
--
-- Take back control by moving the gimbals or sliders.
--
-- Michael Naef, 2018, inspired by JETI's auto Trainer switch
--
local appName="Auto Trainerswitch"
local prevP1, prevP2, prevP3, prevP4, prevP5, prevP6
local audioTrainer = ""
local audioStudent = ""
local vibrateOnTakeback
local beepOnTakeback
local studentSwitch
local takenBack = false
local vibrateCheckbox
local beepCheckbox



local function vibrateCBCallback(value)
	vibrateOnTakeback= not value
	form.setValue(vibrateCheckbox, not value)
	system.pSave("vibrateOnTakeback",value and 0 or 1) -- pSave does not cope with boolean. convert to (!)int
end



local function beepCBCallback(value)
	beepOnTakeback= not value
	form.setValue(beepCheckbox, not value)
	system.pSave("beepOnTakeback",value and 0 or 1) -- pSave does not cope with boolean. convert to (!)int
end



local function initForm(formID)
	form.addRow(2)
	form.addLabel({label="Audio: Teacher in Control",width=200})
	form.addAudioFilebox(audioTrainer, function(value) audioTrainer=value; system.pSave("fileT",value) end)
	
	form.addRow(2)
	form.addLabel({label="Audio: Student in Control",width=200})
	form.addAudioFilebox(audioStudent, function(value) audioStudent=value; system.pSave("fileS",value) end)

	if ( system.getDeviceType() == "JETI DC-24") then -- TODO: DS-24 most likely has vibrating gimbals, as well?
		form.addRow(2)
		form.addLabel({label="Vibrate on takeback",width=270})
		vibrateCheckbox= form.addCheckbox(vibrateOnTakeback, vibrateCBCallback, {alignRight = true})
	end
	
	form.addRow(2)
	form.addLabel({label="beep on takeback",width=270})
	beepCheckbox= form.addCheckbox(beepOnTakeback, beepCBCallback, {alignRight = true})
	
	form.addRow(2)
	form.addLabel({label="Student Switch"})
	form.addInputbox(studentSwitch,true, function(value) studentSwitch=value;system.pSave("studentSwitch",value); end ) 
end	


local function init()
	audioTrainer = system.pLoad("fileT","")
	audioStudent = system.pLoad("fileS","")
	studentSwitch = system.pLoad("studentSwitch") 
	vibrateOnTakeback = system.pLoad("vibrateOnTakeback") == 1 and true or false
	beepOnTakeback = system.pLoad("beepOnTakeback") == 1 and true or false
	system.registerForm(1,MENU_ADVANCED,appName,initForm,keyPressed,printForm);
	-- we need the Control Positions to start with:
	prevP1,prevP2,prevP3,prevP4,prevP5,prevP6 = system.getInputs("P1","P2","P3","P4","P5","P6") 
end



-- 
-- Take back control by moving the control sticks
--
-- Vibrate the left (false), right (true) or both (nil) control sticks
-- and set the Wirelessmode to Teacher
local function takeback(stick)
	system.setProperty("WirelessMode","Teacher")
	takenBack = true
	if (vibrateOnTakeback == true) then
		if (stick ~= nil) then
			system.vibration(stick,3)
		else
			system.vibration(true,2)
			system.vibration(false,2)
		end
	end
	if (beepOnTakeback == true) then
		system.playBeep(0,6000,1000)
	end
	system.playFile(audioTrainer,AUDIO_IMMEDIATE)
end


local function loop() 
	local right = true
	local left = false
	local studentSwitchValue = system.getInputsVal(studentSwitch)
	local WLMode =  system.getProperty("WirelessMode")
	
	-- The studentSwitch switch is set back to "Teacher in Control" after a takeover by
	-- moving the teachers controls. So let's reset the takenBack flag.
	if (WLMode == "Teacher" and studentSwitchValue == -1) then
		takenBack = false
	end

	-- Set the Wirelessmode according to the position of the studentSwitch...
	-- ... to "Teacher in Control"
	if( WLMode == "Student" and studentSwitchValue == -1) then 
		system.setProperty("WirelessMode","Teacher")
		system.playFile(audioTrainer,AUDIO_IMMEDIATE)
	-- ... or to "Student in Control"
	elseif ( WLMode == "Teacher" and studentSwitchValue == 1 and takenBack ~= true ) then
		system.setProperty("WirelessMode","Student")
		prevP1,prevP2,prevP3,prevP4,prevP5,prevP6 = system.getInputs("P1","P2","P3","P4","P5","P6") 
		system.playFile(audioStudent,AUDIO_IMMEDIATE)
	end

	-- Detect wheter the teacher moved his controls by more than a certain amount
	-- since he handed over to the student. If so consider it as a take back.
	if WLMode == "Student"  then
		local P1,P2,P3,P4,P5,P6 = system.getInputs("P1","P2","P3","P4","P5","P6")
		if(math.abs(P1 - prevP1) > 0.1 or math.abs(P2 - prevP2) > 0.1) then
			takeback(right)
		end
		if (math.abs(P3 - prevP3) > 0.1 or math.abs(P4 - prevP4) > 0.1) then
			takeback(left)
		end		 
		if (math.abs(P5 - prevP5) > 0.1 or math.abs(P6 - prevP6) > 0.1) then
			-- nil: vibrate both gimbals to signal the takeback to the teacher
			takeback(nil)
		end		 
	end
end
 

return { init=init, loop=loop, author="Michael Naef, https://modellflug.aeolus.ch/", version="1.00",name=appName}
