# BetterVoiceChannels
(for developers)

# Whats the difference?
The difference is first that if you call "ply:VoiceChannels_GetChannel()"
it returns 2 things first the channel id: "global" for Global ;) and true or false if the 
channel has a password

The hook used there calls "PlayerCanHearPlayersVoice" it calls before the check is done a hook "CustomVCCheck" with listener and talker it should return 2 values 
1. If the user can hear the listener
2. If it can hear each other in 3D ( AND if you dont want to let them hear them: "return false, true" with that it skips the check of the voicechannel)

Thats it :) Its rather for developer a little improvement than for the user itself.

The purpose is if a thirdparty addon want to check if it has a pw to show them or prepare to let the user type in a pw.
