util.AddNetworkString("VoiceChannels_SyncSinglePlayer")
util.AddNetworkString("VoiceChannels_SyncFirstSpawn")
util.AddNetworkString("VoiceChannels_NetworkChatMessage")
util.AddNetworkString("VoiceChannels_DisplayHelpScreen")
util.AddNetworkString("VoiceChannels_SendChannelListings")
util.AddNetworkString("VoiceChannels_CreatedChannel")
util.AddNetworkString("VoiceChannels_RemovedChannel")
util.AddNetworkString("VoiceChannels_ResyncChannel")
util.AddNetworkString("vc_clientgetpwstate")
util.AddNetworkString("vc_syncserver")
util.AddNetworkString("vc_syncclient")

-- announces something to all the members of a certain channel.
voicechannels.AnnounceToChannel = function(chanid, message)
    if chanid and message then
        local foundplayer = nil

        for steamid, channel in pairs(voicechannels.users) do
            if channel == chanid then
                foundplayer = player.GetBySteamID(steamid)

                if foundplayer then
                    voicechannels.AddChatText(foundplayer, message)
                end

                foundplayer = nil
            end
        end
    end
end

-- kicks a player (steamid) from their channel.
voicechannels.KickPlayerFromChannel = function(playerid, reason, silent)
    if playerid and voicechannels.users[playerid] then
        local chanid = string.lower(string.sub(voicechannels.users[playerid], 1, 32))
        local foundplayer = player.GetBySteamID(playerid)
        local newreason = reason or "no reason given."

        if IsValid(foundplayer) and chanid and voicechannels.channels[chanid] then
            voicechannels.AddChatText(foundplayer, "You are being kicked from voice channel #" .. chanid .. ". Reason: " .. newreason)
            foundplayer:VoiceChannels_SetChannel("global")

            if not silent then
                voicechannels.AnnounceToChannel(chanid, "Player " .. foundplayer:Nick() .. " (" .. playerid .. ") was kicked from the channel.")
            end
        end
    else
        return false, "Could not kick player, invalid number of parameters provided"
    end
end

-- syncs a single channel to all clients. mainly called when the password is changed.
voicechannels.SyncSingleChannel = function(chanid)
    if chanid and voicechannels.channels[chanid] then
        net.Start("VoiceChannels_ResyncChannel")
        net.WriteString(chanid)
        net.WriteString(util.TableToJSON(voicechannels.channels[chanid]))
        net.WriteBool(voicechannels.haspasswords[chanid])
        net.Broadcast()
    end
end

-- where the magic happens
hook.Add("PlayerCanHearPlayersVoice", "voicechannels_playercanhearplayersvoice_dovoice", function(listener, talker)
    if IsValid(listener) and IsValid(talker) then
        local hearable, dim = hook.Run("CustomVCCheck", listener, talker)
        if (dim and not hearable) then return false end
        if (hearable) then return hearable, dim end
        local lchan = listener:VoiceChannels_GetChannel()
        local tchan = talker:VoiceChannels_GetChannel()
        -- if players aren't in any channel, don't bother
        if not ((tchan == "global") and (lchan == "global")) then return (lchan == tchan), false end
    end
end)

-- sync all channel and user data to each player when they spawn for cosmetic purposes
hook.Add("PlayerInitialSpawn", "voicechannels_playerinitialspawn_syncallinfo", function(ply)
    if IsValid(ply) then
        timer.Simple(2, function()
            net.Start("VoiceChannels_SyncFirstSpawn")
            net.WriteString(util.TableToJSON(voicechannels.channels))
            net.WriteString(util.TableToJSON(voicechannels.users))
            net.Send(ply)
            voicechannels.AddChatText(ply, "Welcome! This server is using VoiceChannels. Type \"!voice help\" for more info.")
        end)
    end
end)

hook.Add("PlayerSay", "voicechannels_playersay_commandhandler", function(ply, text, public)
    if IsValid(ply) and text then
        if string.StartWith(text, "!voice") then
            local args = string.Explode(" ", text)

            if args[2] then
                if (args[2] == "join") and args[3] then
                    local chanid = args[3]
                    local chanpass = false

                    if args[4] then
                        chanpass = args[4]
                    end

                    if string.sub(chanid, 1, 1) == "#" then
                        chanid = string.sub(chanid, 2, chanid:len())
                    end

                    chanid = string.lower(chanid)
                    local oldchannel = voicechannels.channels[ply:SteamID()]
                    local result, reason = ply:VoiceChannels_SetChannel(chanid, chanpass)

                    if not result then
                        voicechannels.AddChatText(ply, reason)
                    elseif oldchannel then
                        voicechannels.AnnounceToChannel(oldchannel, "Player " .. ply:Nick() .. " (" .. ply:SteamID() .. ") left the channel.")
                    end

                    return ""
                end

                if (args[2] == "kick") then
                    if not args[3] then
                        voicechannels.AddChatText(ply, "You need to supply the name of whoever you want to kick. Use \"all\" to kick everyone except yourself.")

                        return ""
                    end

                    local sid = ply:SteamID()
                    local chanid = nil
                    local reason = "No reason given."

                    if args[4] then
                        reason = table.concat(args, " ", 4)
                    end

                    for possibleid, details in pairs(voicechannels.channels) do
                        if details.admin == sid then
                            chanid = possibleid
                            break
                        end
                    end

                    if chanid then
                        local foundplayer = nil

                        for steamid, channel in pairs(voicechannels.users) do
                            if channel == chanid then
                                foundplayer = player.GetBySteamID(steamid)

                                if IsValid(foundplayer) then
                                    if ((string.find(string.lower(foundplayer:Nick()), string.lower(args[3]), 1, true)) or (string.lower(args[3]) == "all")) and not (foundplayer == ply) then
                                        voicechannels.KickPlayerFromChannel(foundplayer:SteamID(), reason)

                                        return ""
                                    end
                                end
                            end
                        end
                    else
                        voicechannels.AddChatText(ply, "Kick failed, you don't have a channel!")

                        return ""
                    end

                    return ""
                end

                if (args[2] == "kickid") then
                    if not args[3] then
                        voicechannels.AddChatText(ply, "You need to supply the SteamID of whoever you want to kick.")

                        return ""
                    end

                    local sid = ply:SteamID()
                    local chanid = nil
                    local reason = "No reason given."

                    if args[4] then
                        reason = table.concat(args, " ", 4)
                    end

                    for possibleid, details in pairs(voicechannels.channels) do
                        if details.admin == sid then
                            chanid = possibleid
                            break
                        end
                    end

                    if chanid then
                        local foundplayer = nil

                        for steamid, channel in pairs(voicechannels.users) do
                            if channel == chanid then
                                foundplayer = player.GetBySteamID(steamid)

                                if IsValid(foundplayer) then
                                    if string.lower(foundplayer:SteamID()) == string.lower(args[3]) then
                                        voicechannels.KickPlayerFromChannel(foundplayer:SteamID(), reason)

                                        return ""
                                    end
                                end
                            end
                        end
                    else
                        voicechannels.AddChatText(ply, "Kick failed, you don't have a channel!")

                        return ""
                    end

                    return ""
                end

                if (args[2] == "leave") then
                    local sid = ply:SteamID()
                    local chanid = "global"

                    if voicechannels.users[sid] then
                        chanid = voicechannels.users[sid]
                    end

                    if string.sub(chanid, 1, 1) == "#" then
                        chanid = string.sub(chanid, 2, chanid:len())
                    end

                    if not (chanid == "global") then
                        voicechannels.AnnounceToChannel(chanid, "Player " .. ply:Nick() .. " (" .. ply:SteamID() .. ") left the channel.")
                        voicechannels.AddChatText(ply, "You are now talking in global voice chat.")
                        local result, reason = ply:VoiceChannels_SetChannel("global", false)

                        if not result then
                            voicechannels.AddChatText(ply, reason)
                        end
                    else
                        voicechannels.AddChatText(ply, "You are currently in the global channel. To join a different channel, use \"!voice join <channelname> <optionalpassword>\"")
                    end

                    return ""
                end

                if (args[2] == "password") then
                    local newpass = false

                    if args[3] then
                        newpass = args[3]
                    end

                    local sid = ply:SteamID()
                    local chanid = nil

                    for possibleid, details in pairs(voicechannels.channels) do
                        if details.admin == sid then
                            chanid = possibleid
                            break
                        end
                    end

                    if chanid then
                        if newpass then
                            voicechannels.haspasswords[chanid] = true
                            voicechannels.passwords[chanid] = newpass
                            voicechannels.AddChatText(ply, "You set the password for #" .. chanid .. " to \"" .. newpass .. "\"")
                            voicechannels.AnnounceToChannel(chanid, "The channel password was changed.")
                        else
                            voicechannels.haspasswords[chanid] = false
                            voicechannels.passwords[chanid] = nil
                            voicechannels.AddChatText(ply, "You removed the password for #" .. chanid .. ".")
                            voicechannels.AnnounceToChannel(chanid, "The channel password was removed.")
                        end

                        voicechannels.SyncSingleChannel(chanid)
                    else
                        voicechannels.AddChatText(ply, "Couldn't set channel password - you don't have a channel!")
                    end

                    return ""
                end

                if (args[2] == "create") then
                    if not args[3] then
                        voicechannels.AddChatText(ply, "You need to supply the name of your channel. Example: \"!voice create #channelname\"")

                        return ""
                    end

                    local chanid = args[3]
                    local chanpass = false

                    if args[4] then
                        chanpass = args[4]
                    end

                    if string.sub(chanid, 1, 1) == "#" then
                        chanid = string.sub(chanid, 2, chanid:len())
                    end

                    local result, reason = voicechannels.NewChannel(chanid, ply:SteamID(), chanpass)

                    if not result then
                        voicechannels.AddChatText(ply, reason)
                    end

                    return ""
                end

                if (args[2] == "remove") then
                    local sid = ply:SteamID()
                    local todeleteid = false

                    for chanid, details in pairs(voicechannels.channels) do
                        if details.admin == sid then
                            todeleteid = chanid
                            break
                        end
                    end

                    if todeleteid then
                        local result, reason = voicechannels.RemoveChannel(todeleteid)

                        if not result then
                            voicechannels.AddChatText(ply, reason)
                        end
                    else
                        voicechannels.AddChatText(ply, "You don't have any channels!")
                    end

                    return ""
                end

                if (args[2] == "list") then
                    local sid = ply:SteamID()
                    local todeleteid = false
                    local temp = {}
                    local count = 1

                    for chanid, details in pairs(voicechannels.channels) do
                        temp[count] = {
                            name = "#" .. chanid,
                            private = false,
                        }

                        local foundplayer = player.GetBySteamID(sid)

                        if foundplayer then
                            temp[count].admin = foundplayer:Nick() .. " (" .. foundplayer:SteamID() .. ")"
                        else
                            temp[count].admin = foundplayer:SteamID()
                        end

                        foundplayer = nil

                        if voicechannels.passwords[chanid] then
                            temp[count].private = true
                        end

                        count = count + 1
                    end

                    net.Start("VoiceChannels_SendChannelListings")
                    net.WriteString(util.TableToJSON(temp))
                    net.Send(ply)

                    return ""
                end

                if (args[2] == "help") then
                    net.Start("VoiceChannels_DisplayHelpScreen")
                    net.Send(ply)

                    return ""
                end
            else
                local curchanid = ply:VoiceChannels_GetChannel()
                local sid = ply:SteamID()
                local temp = "Current channel: #" .. curchanid

                if voicechannels.passwords[curchanid] then
                    temp = temp .. " (passworded)"
                end

                voicechannels.AddChatText(ply, temp)
                temp = "Others in channel: "
                local count = 0

                for k, v in pairs(player.GetAll()) do
                    if (v:VoiceChannels_GetChannel() == curchanid) and not (v:SteamID() == sid) then
                        count = count + 1

                        if count == 1 then
                            temp = temp .. v:Nick()
                        else
                            temp = temp .. ", " .. v:Nick()
                        end
                    end
                end

                if count == 0 then
                    temp = temp .. "(nobody)"
                end

                voicechannels.AddChatText(ply, temp)

                return ""
            end
        end
    end
end)

net.Receive("vc_syncclient", function(len)
    voicechannels.haspasswords[net.ReadString()] = net.ReadBool()
end)