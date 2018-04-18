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
local TSControlIdx = nil
local TSMode = nil

-- Pseudo Constants
local STUDENT= 1
local TEACHER= 0
local VBR_LEFT = false
local VBR_RIGHT = true
local VBR_NONE = nil
local VBR_BOTH = "both"



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

	form.addRow(1)
	form.addLabel({label=""})
	form.addRow(1)
	form.addLabel({label="To use the Auto Trainerswitch function"})
	form.addRow(1)
	form.addLabel({label="select 'Apps' -> 'T/S' as trainerswitch"})
	form.addRow(1)
	form.addLabel({label="in the set-up of the model options."})
end	


--
-- Switch between TEACHER and STUDENT mode
--
-- Update the value of the registered Control / Function
-- as well as the app internal Trainer/Studen-Mode which tracks our state
local function switchTSMode(state)
	if(TSControlIdx) then
		system.setControl(TSControlIdx,state,0)
		TSMode = state;
		--print("switchTSMode("..state..")");
		return(true)
	end
	return(false)
end


-- 
-- Take back control from the student
--
-- Vibrate the control sticks and set the TSMode to TEACHER
local function takeback(stick)
	--print ("takeback()")
	if (switchTSMode(TEACHER)) then
		takenBack = true
		if (vibrateOnTakeback == true) then
			if (stick ~= VBR_NONE) then
				if (stick == VBR_BOTH) then
					system.vibration(true,2)
					system.vibration(false,2)
				else
					system.vibration(stick,3)
				end
			end
		end
		if (beepOnTakeback == true and stick ~= VBR_NONE) then
			system.playBeep(0,5000,700)
		end
		system.playFile(audioTrainer,AUDIO_IMMEDIATE)
	end -- else: TODO: Error
end


--
-- Give the control over to the student
--
local function giveover()
	--print ("giveover()")
	if (switchTSMode(STUDENT)) then
		system.playFile(audioStudent,AUDIO_IMMEDIATE)
	end -- else: TODO: Error
end


--
-- initialize the data strctures of the app
--
local function init()
	audioTrainer = system.pLoad("fileT","")
	audioStudent = system.pLoad("fileS","")
	studentSwitch = system.pLoad("studentSwitch") 
	vibrateOnTakeback = system.pLoad("vibrateOnTakeback") == 1 and true or false
	beepOnTakeback = system.pLoad("beepOnTakeback") == 1 and true or false
	system.registerForm(1,MENU_ADVANCED,appName,initForm,keyPressed,printForm);
	TSControlIdx = system.registerControl(1, "Auto Trainer Switch","T/S")
	if (system.getInputsVal(studentSwitch) == 1 ) then
		giveover();
	else
		takeback(VBR_NONE);
	end	
	-- we need the Control Positions to start with:
	prevP1,prevP2,prevP3,prevP4,prevP5,prevP6 = system.getInputs("P1","P2","P3","P4","P5","P6") 
end


--
-- our main loop :)
--
local function loop()
	if (system.getProperty("WirelessMode") == "Teacher") then -- only work when the TX Wirelessmode is actually Teacher
		local studentSwitchValue = system.getInputsVal(studentSwitch)
		
		-- Reset the takenBack flag if both the TSMode and the TSSwitch are
		-- are set to TEACHER.
		if (TSMode == TEACHER and studentSwitchValue ~= STUDENT and takenBack == true) then
			takenBack = false
		end

		-- The studentSwitch has just been set to TEACHER
		if( TSMode == STUDENT and studentSwitchValue ~= STUDENT) then 
			takeback(VBR_NONE)
		-- The studentSwitch has just been set to STUDENT
		elseif ( TSMode == TEACHER and studentSwitchValue == STUDENT and takenBack ~= true ) then
			prevP1,prevP2,prevP3,prevP4,prevP5,prevP6 = system.getInputs("P1","P2","P3","P4","P5","P6") 
			giveover()
		end

		-- In STUDENT mode:
		-- Detect wheter the teacher moved his controls by more than a certain amount
		-- since he handed over the control to the student.
		-- If so, consider it as a take back.
		if TSMode == STUDENT  then
			local P1,P2,P3,P4,P5,P6 = system.getInputs("P1","P2","P3","P4","P5","P6")
			if(math.abs(P1 - prevP1) > 0.1 or math.abs(P2 - prevP2) > 0.1) then
				takeback(VBR_RIGHT)
			end
			if (math.abs(P3 - prevP3) > 0.1 or math.abs(P4 - prevP4) > 0.1) then
				takeback(VBR_LEFT)
			end
			if (math.abs(P5 - prevP5) > 0.1 or math.abs(P6 - prevP6) > 0.1) then
				-- nil: vibrate both gimbals to signal the takeback to the teacher
				takeback(VBR_BOTH)
			end
		end
	end
end
 

return { init=init, loop=loop, author="Michael Naef, https://modellflug.aeolus.ch/", version="1.0.0",name=appName}
