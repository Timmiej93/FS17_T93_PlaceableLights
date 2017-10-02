-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- PlaceableLights
--
-- Purpose: Adding functionality to placeable lights
--               Events for synching placementobject and light state
--
-- Authors: Timmiej93
--
-- Copyright (c) Timmiej93, 2017
-- For more information on copyright for this mod, please check the readme file on Github
--
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

PlaceableLightsManagerEvent = {};
PlaceableLightsManagerEvent_mt = Class(PlaceableLightsManagerEvent, Event);

InitEventClass(PlaceableLightsManagerEvent, "PlaceableLightsManagerEvent");

function PlaceableLightsManagerEvent:emptyNew()
    local self = Event:new(PlaceableLightsManagerEvent_mt);
    return self;
end

function PlaceableLightsManagerEvent:new()
    local self = PlaceableLightsManagerEvent:emptyNew()

    self.customEnvironment = PlaceableLightsManager.placeableObjectEnvironment
    self.currentGhostHeight = PlaceableLightsManager.currentGhostHeight

    return self;
end

function PlaceableLightsManagerEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.customEnvironment)
    streamWriteFloat32(streamId, self.currentGhostHeight)
end

function PlaceableLightsManagerEvent:readStream(streamId, connection)
    self.customEnvironment = streamReadString(streamId)
    self.currentGhostHeight = streamReadFloat32(streamId)
    self:run()
end

function PlaceableLightsManagerEvent:run(connection)
    g_currentMission.PlaceableLightsManager.placeableObjectEnvironment = self.customEnvironment
    g_currentMission.PlaceableLightsManager.currentGhostHeight = self.currentGhostHeight
end

function PlaceableLightsManagerEvent.sendEvent()
    if g_server == nil then 
        g_client:getServerConnection():sendEvent(PlaceableLightsManagerEvent:new());
    end;
end


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- Events
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

PlaceableLightsEvent = {};
PlaceableLightsEvent_mt = Class(PlaceableLightsEvent, Event);

InitEventClass(PlaceableLightsEvent, "PlaceableLightsEvent");

function PlaceableLightsEvent:emptyNew()
    local self = Event:new(PlaceableLightsEvent_mt);
    return self;
end

function PlaceableLightsEvent:new(lamp)
    local self = PlaceableLightsEvent:emptyNew()

    self.lamp = lamp;

    self.currentLightState = lamp.currentLightState;
    self.activeLightColor = lamp.activeLightColor;
    self.currentBrightness = lamp.currentBrightness;

    self.y = -9999
    if lamp.raisableElement ~= nil then
        _,self.y,_ = getTranslation(lamp.raisableElement);
    end

    self.rY = -9999
    if lamp.rotateableElement ~= nil then
        _,self.rY,_ = getRotation(lamp.rotateableElement);
    end

    return self;
end

function PlaceableLightsEvent:writeStream(streamId, connection)

    streamWriteInt32(streamId, networkGetObjectId(self.lamp));

    streamWriteInt8(streamId, self.currentLightState);
    streamWriteInt8(streamId, self.activeLightColor);
    streamWriteInt8(streamId, self.currentBrightness);

    streamWriteFloat32(streamId, self.y)
    streamWriteFloat32(streamId, self.rY)
end

function PlaceableLightsEvent:readStream(streamId, connection)
    self.lamp = networkGetObject(streamReadInt32(streamId));

    self.currentLightState = streamReadInt8(streamId)
    self.activeLightColor = streamReadInt8(streamId)
    self.currentBrightness = streamReadInt8(streamId)

    self.y = streamReadFloat32(streamId)
    self.rY = streamReadFloat32(streamId)

    self:run(connection);
end

function PlaceableLightsEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.lamp);
    end
    if self.lamp ~= nil then
    	self.lamp.currentLightState = self.currentLightState
    	self.lamp.activeLightColor = self.activeLightColor

        self.lamp:setLightState();
        self.lamp:setLightColor();

        if self.lamp.lightColors ~= nil then
            for _,light in pairs(self.lamp.lightColors) do
                setLightRange(light.lightSource, self.currentBrightness)
            end
        end

        if self.y ~= nil and self.y ~= -9999 then
            setTranslation(self.lamp.raisableElement, 0,self.y,0);
        end

        if self.rY ~= nil and self.rY ~= -9999 then
            setRotation(self.lamp.rotateableElement, 0,self.rY, 0);
        end
    end
end

function PlaceableLightsEvent.sendEvent(lamp)
    if g_server ~= nil then 
        g_server:broadcastEvent(PlaceableLightsEvent:new(lamp), nil, nil, lamp);
    else
        g_client:getServerConnection():sendEvent(PlaceableLightsEvent:new(lamp));
    end;
end
