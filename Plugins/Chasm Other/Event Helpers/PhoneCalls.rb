def phoneCallSE()
	msgwindow = pbCreateMessageWindow()
	pbMessageDisplay(msgwindow,_INTL("\\se[PhoneRinging]Ring ring..."))
	pbWait(20)
	pbDisposeMessageWindow(msgwindow)
	Input.update
end

def phoneCall(caller=_INTL("Unknown"),eventSwitch=nil)
	phoneCallSE()
	setMySwitch(eventSwitch,true) if eventSwitch
	if !pbConfirmMessage(_INTL("\\i[SMARTPHONE]...It's {1}. Pick up the phone?", caller))
		phoneCallEnd()
		command_end
		return
	end	
end

def phoneCallConditional(caller=_INTL("Unknown"))
	phoneCallSE()
	if !pbConfirmMessage(_INTL("\\i[SMARTPHONE]...It's {1}. Pick up the phone?", caller))
		pbSEFade(1.0)
		phoneCallEnd()
		return false
	end
	pbSEFade(1.0)
	return true
end

def phoneCallEnd()
	removeSpeaker
	pbMessage(_INTL("\\i[SMARTPHONE]\\se[Voltorb Flip mark]Click."))
	pbWait(40)
end