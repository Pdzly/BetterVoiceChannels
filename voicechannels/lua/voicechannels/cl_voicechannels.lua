local overlayCvar = CreateClientConVar("voicechannels_drawoverlay", "1", true, false)
local vc_black = Color(20, 20, 20, 245)
local vc_white = color_white
local vcicon = Material("icon16/transmit_blue.png", "noclamp")
local vciconorange = Material("icon16/transmit.png", "noclamp")
voicechannels.listactive = false

surface.CreateFont("voicechannels_overlayfont", {
    font = "Roboto",
    extended = false,
    size = 18,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = true,
    additive = false,
    outline = false,
})

hook.Add("HUDPaint", "voicechannels_hudpaint_overlay", function()
    if overlayCvar:GetBool() then
        local ply = LocalPlayer()
        local sid = ply:SteamID()
        local chanid = voicechannels.users[sid]
        local channame = ""

        if not chanid then
            channame = "No channel (Type \"!voice list\" to see all channels)"
        else
            channame = "Talking in #" .. chanid .. ""
        end

        surface.SetFont("voicechannels_overlayfont")
        local tw = surface.GetTextSize(channame)
        local sw = ScrW()
        draw.RoundedBoxEx(4, sw - tw - 48, 8, tw + 40, 32, vc_black, true, true, true, true)
        draw.DrawText(channame, "voicechannels_overlayfont", ScrW() - 16, 15, vc_white, TEXT_ALIGN_RIGHT)

        if ply:IsSpeaking() then
            surface.SetMaterial(vciconorange)
        else
            surface.SetMaterial(vcicon)
        end

        surface.SetDrawColor(color_white)
        surface.DrawTexturedRect(sw - tw - 40, 16, 16, 16)
    end
end)

-- syncing a player's info
net.Receive("VoiceChannels_SyncSinglePlayer", function(len)
    local player = net.ReadEntity()
    local chanid = net.ReadString()

    if IsValid(player) and chanid then
        if chanid == "global" then
            voicechannels.users[player:SteamID()] = nil
        else
            player:VoiceChannels_SetChannel(chanid)
        end
    end
end)

-- syncing all info, channels and players
net.Receive("VoiceChannels_SyncFirstSpawn", function(len)
    local chantablestring = net.ReadString()
    local usertablestring = net.ReadString()
    voicechannels.channels = table.Copy(util.JSONToTable(chantablestring))
    voicechannels.users = table.Copy(util.JSONToTable(usertablestring))
end)

-- networked chat data
net.Receive("VoiceChannels_NetworkChatMessage", function(len)
    local cjson = net.ReadString()

    if cjson then
        voicechannels.AddChatText(unpack(util.JSONToTable(cjson)))
    end
end)

-- networked chat listings
net.Receive("VoiceChannels_SendChannelListings", function(len)
    local pstring = net.ReadString()

    if pstring then
        local chandata = util.JSONToTable(pstring)
        local frameblack = vc_black or Color(22, 22, 22, 250) -- shitty workaround
        local listingframe = vgui.Create("DFrame")
        listingframe:SetSize(500, 400)
        listingframe:Center()
        listingframe:SetTitle("Channel Listings")
        listingframe:MakePopup()

        function listingframe:Paint(w, h)
            draw.RoundedBoxEx(4, 0, 0, w, h, frameblack, true, true, true, true)
        end

        listingframe.listings = vgui.Create("RichText", listingframe)
        listingframe.listings:Dock(FILL)

        function listingframe.listings:PerformLayout()
            self:SetFontInternal("voicechannels_overlayfont")
            self:SetFGColor(Color(255, 255, 255))
        end

        for k, chantable in pairs(chandata) do
            listingframe.listings:InsertColorChange(100, 195, 235, 255)
            listingframe.listings:AppendText(chantable.name)

            if chantable.private then
                listingframe.listings:AppendText("  [PRIVATE]")
            end

            listingframe.listings:InsertColorChange(225, 225, 225, 255)
            listingframe.listings:AppendText("\n    Created by " .. chantable.admin .. "\n\n")
        end
    end
end)

-- help screen
net.Receive("VoiceChannels_DisplayHelpScreen", function(len)
    local frameblack = vc_black or Color(22, 22, 22, 250) -- shitty workaround
    local helpframe = vgui.Create("DFrame")
    helpframe:SetSize(500, 400)
    helpframe:Center()
    helpframe:SetTitle("VoiceChannels Help")
    helpframe:MakePopup()

    function helpframe:Paint(w, h)
        draw.RoundedBoxEx(4, 0, 0, w, h, frameblack, true, true, true, true)
    end

    helpframe.helpbox = vgui.Create("RichText", helpframe)
    helpframe.helpbox:Dock(FILL)

    function helpframe.helpbox:PerformLayout()
        self:SetFontInternal("voicechannels_overlayfont")
        self:SetFGColor(Color(255, 255, 255))
    end

    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("ABOUT VOICECHANNELS\n")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText("VoiceChannels lets you create private voice chat channels. This addon works well on build servers, or if you just want a private voice channel.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("CHAT COMMANDS\n")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText("VoiceChannels is controlled through chat commands. Here is the full list:\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - tells you about your current channel.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice help")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - displays this window!\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice list")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - shows you every channel that has been created.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice join <#channel> <password>")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - joins a channel. The password parameter is optional.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice leave")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - leaves your current channel.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice create <#channelname> <password>")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - creates a new channel. You can only create one channel at a time. The password is optional.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice remove")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - removes your channel.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice password <password>")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - changes the password on your channel. If the password is left out, the password will be removed.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice kick <playername|all> <reason>")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - kicks someone from your channel. If you choose to kick \"all\", everyone but you will be kicked from the channel. The reason is optional.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("!voice kickid <steamid> <reason>")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText(" - kicks someone with a particular SteamID from your channel. The reason is optional.\n\n")
    helpframe.helpbox:InsertColorChange(100, 195, 235, 255)
    helpframe.helpbox:AppendText("DISABLING THE OVERLAY\n")
    helpframe.helpbox:InsertColorChange(225, 225, 225, 255)
    helpframe.helpbox:AppendText("To disable the overlay at the top right, you can run \"voicechannels_drawoverlay 0\" in your console. To turn the overlay back on, just set the ConVar back to 1: \"voicechannels_drawoverlay 1\"\n\n")
end)

-- when a new channel is born
net.Receive("VoiceChannels_CreatedChannel", function(len)
    local chanid = net.ReadString()
    local chantablestring = net.ReadString()

    if chanid and chantablestring then
        local ctbl = util.JSONToTable(chantablestring)
        voicechannels.NewChannel(chanid, ctbl.admin)
		voicechannels.haspasswords[chanid] = net.ReadBool()
    end
end)

-- when a channel is killed
net.Receive("VoiceChannels_RemovedChannel", function(len)
    local chanid = net.ReadString()

    if chanid then
        voicechannels.RemoveChannel(chanid)
    end
end)

-- called when resyncing a channel is necessary
net.Receive("VoiceChannels_ResyncChannel", function(len)
    local chanid = net.ReadString()
    local chantablestring = net.ReadString()

    if chanid and chantablestring then
        voicechannels.channels[chanid] = util.JSONToTable(chantablestring)
		voicechannels.haspasswords[chanid] = net.ReadBool()
    end
end)

net.Receive("vc_syncserver", function(len)
    voicechannels.haspasswords[net.ReadString()] = net.ReadBool()
end)
