voicechannels = voicechannels or {
    channels = {},
    users = {},
    passwords = {},
    haspasswords = {
        global = false,
    },
    istalking = false,
}

-- chat networking :(((
voicechannels.AddChatText = function(...)
    local ctbl = {...}

    local ply = ctbl[1]

    if SERVER then
        if ply then
            local cjson = util.TableToJSON(ctbl)

            if not (type(ply) == "string") then
                table.remove(ctbl, 1)
                cjson = util.TableToJSON(ctbl)
                net.Start("VoiceChannels_NetworkChatMessage")
                net.WriteString(cjson)
                net.Send(ply)
            else
                net.Start("VoiceChannels_NetworkChatMessage")
                net.WriteString(cjson)
                net.Broadcast()
            end
        end
    end

    if CLIENT then
        table.insert(ctbl, 1, color_white)
        table.insert(ctbl, 1, "[VoiceChannels] ")
        table.insert(ctbl, 1, Color(100, 195, 235))
        chat.AddText(unpack(ctbl))
    end
end

-- voicechannels.NewChannel
-- returns two values: boolean (channel created) and string (reason why the creation failed, if it did)
voicechannels.NewChannel = function(chanid, adminid, chanpass)
    if chanid and adminid then
        -- limit lengths
        local newid = string.lower(chanid:sub(1, 32))
        if newid == "global" then return false, "You cannot recreate the Global Channel!" end

        if SERVER then
            -- iterate through the current channels and check for conflicts
            for otherid, otherdetails in pairs(voicechannels.channels) do
                if otherid == newid then
                    return false, "Channel #" .. newid .. " already exists."
                elseif otherdetails.admin == adminid then
                    return false, "You already have a channel! (#" .. otherid .. ") Use \"!voice remove\" to delete it."
                end
            end

            -- at this point we can safely assume that there are no conflicts, and create the channel
            voicechannels.channels[newid] = {
                admin = adminid,
            }

            voicechannels.haspasswords[newid] = false

            if chanpass then
                voicechannels.passwords[newid] = chanpass
                voicechannels.haspasswords[newid] = true
            end

            if (SERVER) then
                net.Start("VoiceChannels_CreatedChannel")
                net.WriteString(newid)
                net.WriteString(util.TableToJSON(voicechannels.channels[newid]))
                net.WriteBool(voicechannels.haspasswords[newid])
                net.Broadcast()
            end

            if (CLIENT) then
                net.Start("vc_sync")
                net.WriteString(newid)
                net.WriteBool(voicechannels.haspasswords[newid])
                net.SendToServer()
            end

            return true
        end

        if CLIENT then
            -- info expected to arrive from the server
            voicechannels.channels[newid] = {
                admin = adminid,
            }

            voicechannels.haspasswords[newid] = true
            voicechannels.AddChatText("Voice channel #" .. newid .. " has been created.")

            return true
        end
    else
        return false, "Invalid channel options provided."
    end
end

-- voicechannels.RemoveChannel
-- returns two values: boolean (channel deleted) and string (reason why the deletion failed, if it did)
voicechannels.RemoveChannel = function(chanid)
    if chanid then
        -- limit lengths
        local newid = string.lower(chanid:sub(1, 32))
        if newid == "global" then return false, "Can't remove the global channel..." end
        if not voicechannels.channels[newid] then return false, "That channel doesn't exist." end

        if SERVER then
            for playerid, channelid in pairs(voicechannels.users) do
                if channelid == newid then
                    voicechannels.KickPlayerFromChannel(playerid, "Channel is being deleted.", true)
                end
            end

            local chanadmin = player.GetBySteamID(voicechannels.channels[newid].admin)
            voicechannels.channels[newid] = nil
            voicechannels.passwords[newid] = nil
            voicechannels.haspasswords[newid] = nil

            if chanadmin then
                voicechannels.AddChatText(chanadmin, "Your voice channel has been deleted successfully.")
            end

            net.Start("VoiceChannels_RemovedChannel")
            net.WriteString(newid)
            net.Broadcast()

            return true
        end

        if CLIENT then
            -- info expected to arrive from the server
            voicechannels.channels[newid] = nil
            voicechannels.AddChatText("Voice channel #" .. newid .. " has been deleted.")

            return true
        end
    else
        return false, "Invalid channel options provided."
    end
end

-- player methods
local plymeta = FindMetaTable("Player")

-- set player's voice channel
function plymeta:VoiceChannels_SetChannel(chanid, chanpass)
    if IsValid(self) then
        if voicechannels.channels[chanid] or (chanid == "global") then
            if SERVER then
                if chanid == "global" then
                    voicechannels.users[self:SteamID()] = nil
                else
                    local success = false

                    if voicechannels.passwords[chanid] then
                        if voicechannels.passwords[chanid] == chanpass then
                            success = true
                        end
                    else
                        success = true
                    end

                    if success then
                        voicechannels.users[self:SteamID()] = chanid
                        voicechannels.AddChatText(self, "You are now talking in #" .. chanid .. ".")
                        voicechannels.AnnounceToChannel(chanid, "Player " .. self:Nick() .. " (" .. self:SteamID() .. ") joined the channel.")
                    else
                        return false, "Could not join the channel - incorrect password."
                    end
                end

                net.Start("VoiceChannels_SyncSinglePlayer")
                net.WriteEntity(self)
                net.WriteString(chanid)
                net.Broadcast()

                return true
            end

            if CLIENT then
                -- from server
                voicechannels.users[self:SteamID()] = chanid
            end
        else
            return false, "Channel #" .. chanid .. " does not exist. You can create it by typing \"!voice create #" .. chanid .. "\""
        end
    end
end

-- get player's voice channel
function plymeta:VoiceChannels_GetChannel()
    if IsValid(self) then
        local channel = voicechannels.users[self:SteamID()] or "global"
        local haspw = false
        haspw = voicechannels.haspasswords[channel]

        return channel, haspw
    end
end



if SERVER then
    AddCSLuaFile("voicechannels/cl_voicechannels.lua")
    include("voicechannels/sv_voicechannels.lua")
end

if CLIENT then
    include("voicechannels/cl_voicechannels.lua")
end