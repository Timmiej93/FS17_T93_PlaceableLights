PlaceableLights = {};
PlaceableLights_mt = Class(PlaceableLights, Placeable);
InitObjectClass(PlaceableLights, "PlaceableLights");
registerPlaceableType("placeableLights", PlaceableLights);

PlaceableLightsManager = {}

PlaceableLightsManager.modName = g_currentModName;

function PlaceableLights:new()
    local self = Placeable:new(g_server ~= nil, g_client ~= nil, PlaceableLights_mt);
    registerObjectClassName(self, "PlaceableLights");
    return self;
end;

function PlaceableLights:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
    if not PlaceableLights:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
        return false;
    end

    self.xmlFile = loadXMLFile("TempXML", xmlFilename);
    if self.xmlFile == 0 or self.xmlFile == nil then
    	print("XML file not found!")
    end
    
    -- Two second timer
    self.timer2sec = 0;
    self.timer2secActive = false;

    -- Light staes
    self.lightStates = {
        [1] = g_i18n:getText("button_lightBehavior_automatic"),
        [2] = g_i18n:getText("button_lightBehavior_alwaysOn"),
        [3] = g_i18n:getText("button_lightBehavior_alwaysOff")
    }
    self.light = Utils.indexToObject(self.nodeId, Utils.getNoNil(getUserAttribute(self.nodeId, "lighting"), 0));
	self.currentLightState = 1;

    -- Trigger
    self.playerTrigger = Utils.indexToObject(self.nodeId, Utils.getNoNil(getUserAttribute(self.nodeId, "playerTrigger"), 1));
    self.playersInTrigger = false;

    -- Height alterations
    self.alignmentGuide = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId, "alignmentGuide"));
	self.raisableElement = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId, "variableHeight"))
    
    if self.xmlFile ~= 0 and self.xmlFile ~= nil and self.alignmentGuide ~= nil and self.raisableElement then
    	local coarseHeight = getXMLFloat(self.xmlFile, "placeable.placeableLight#coarseHeightChange");
    	local fineHeight = getXMLFloat(self.xmlFile, "placeable.placeableLight#fineHeightChange");
    	local ultraFineHeight = getXMLFloat(self.xmlFile, "placeable.placeableLight#ultraFineHeightChange");
    	if coarseHeight == nil or fineHeight == nil or ultraFineHeight == nil then
    		print("ERROR: There was an issue with loading data from the XML file!")
    	else
    		self.adjustHeights = {};
    		self.adjustHeights[1] = {["height"] = coarseHeight, ["text"] = g_i18n:getText("button_height_changeStepSize_Coarse")}
    		self.adjustHeights[2] = {["height"] = fineHeight, ["text"] = g_i18n:getText("button_height_changeStepSize_Fine")}
    		self.adjustHeights[3] = {["height"] = ultraFineHeight, ["text"] = g_i18n:getText("button_height_changeStepSize_UltraFine")}
    		self.activeHeight = 1;
    	end
    end

    -- Color variations
    local whiteLight = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId, "lightingWhite"));
    local orangeLight = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId, "lightingOrange"));

    self.lightColors = {
        [1] = {["text"] = g_i18n:getText("button_changeColor_white"), ["lightElement"] = whiteLight},
        [2] = {["text"] = g_i18n:getText("button_changeColor_orange"), ["lightElement"] = orangeLight},
    }
    self.activeLightColor = 1;

    for _,light in pairs(self.lightColors) do
        light.lightSource = getChild(light.lightElement, "lightSource");
        light.corona = getChild(light.lightElement, "corona")
    end

	self.currentBrightness = getLightRange(self.lightColors[1].lightSource);

    if PlaceableLightsManager.ghost == nil and g_gui.currentGui == (g_gui.guis.PlacementScreen or g_gui.guis.ShopScreen) then
        PlaceableLightsManager.ghost = self;
    end

    return true;
end

function PlaceableLights:finalizePlacement()
    PlaceableLights:superClass().finalizePlacement(self);
    g_currentMission.environment:addWeatherChangeListener(self);

    if self.playerTrigger ~= nil then
        addTrigger(self.playerTrigger, "PlayerTriggerCallback", self);
    end

    if self.alignmentGuide ~= nil then
    	setVisibility(self.alignmentGuide, false);
    end

    for _,light in pairs(self.lightColors) do
    	if light.corona ~= 0 and light.corona ~= nil then
    		setVisibility(light.corona, true);
    	end
    end

    if PlaceableLightsManager.currentGhostHeight ~= nil and PlaceableLightsManager.currentGhostHeight ~= 0 and self.raisableElement ~= nil then
        local x,_,z = getTranslation(self.raisableElement)
        setTranslation(self.raisableElement, x, PlaceableLightsManager.currentGhostHeight, z)
        PlaceableLightsManager.currentGhostHeight = 0;
    end
    self:setLightState();
    self:setLightColor();
end

function PlaceableLights:delete()
    if self.playerTrigger ~= nil then
        removeTrigger(self.playerTrigger)
    end

    if PlaceableLightsManager.ghost ~= nil then
        PlaceableLightsManager.ghost = nil
    end

    if g_currentMission.environment ~= nil then
        g_currentMission.environment:removeWeatherChangeListener(self);
    end;

	unregisterObjectClassName(self);
    PlaceableLights:superClass().delete(self);
end;

function PlaceableLights:deleteExtra()
    if PlaceableLightsManager.ghost ~= nil then
        PlaceableLightsManager.ghost = nil;
    end
end
g_gui.guis.PlacementScreen.onCloseCallback = Utils.appendedFunction(g_gui.guis.PlacementScreen.onCloseCallback, PlaceableLights.deleteExtra)


function PlaceableLights:weatherChanged()
    if self.currentLightState == 1 and g_currentMission ~= nil and g_currentMission.environment ~= nil then
        setVisibility(self.light, not (g_currentMission.environment.isSunOn and g_currentMission.environment.currentRain == nil));
    end;
end;

function PlaceableLights:setLightState()
    if self.currentLightState == 1 then
        self:weatherChanged();
    elseif self.currentLightState == 2 then
        setVisibility(self.light, true);
    elseif self.currentLightState == 3 then
        setVisibility(self.light, false);
    end
end

function PlaceableLights:activateTimer()
    -- Enable light for two seconds, override other controls
    self.timer2secActive = true;
    self.timer2sec = 0;
    setVisibility(self.light, true);
end

function PlaceableLights:setLightColor()
    local found = false;
    for i,lightTable in pairs(self.lightColors) do
        if i == self.activeLightColor then
            setVisibility(lightTable.lightElement, true);
            found = true;
        else
            setVisibility(lightTable.lightElement, false);
        end
    end
    if not found then
        self.activeLightColor = 1;
        self:setLightColor();
    end
    self:activateTimer();
end

function PlaceableLights:update(dt)
    -- Two second timer
    if self.timer2secActive then
        if self.timer2sec < 2000 then
            self.timer2sec = self.timer2sec + dt;
            self.timer2secThrough = false;
        else
            self.timer2sec = 0;
            self.timer2secThrough = true;
            self.timer2secActive = false;
        end;
    end

    if self.timer2secThrough then
        self.timer2secThrough = false;
        self:setLightState();
    end

    -- When player is in trigger
    if self.playersInTrigger then
        if g_gui.currentGui ~= nil then
            self.chatDialogOpen = (g_gui.currentGui.name == "ChatDialog");
        else
            self.chatDialogOpen = false;
        end

    	-- Change light behavior
        g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_lightBehavior"), self.lightStates[self.currentLightState]), InputBinding.changeLightBehavior);
        if InputBinding.hasEvent(InputBinding.changeLightBehavior) and not self.chatDialogOpen then
            self.currentLightState = self.currentLightState + 1;
            if self.currentLightState > #(self.lightStates) then
                self.currentLightState = 1;
            end

            if not self.timer2secActive then
                self:setLightState();
            end
            PlaceableLightsEvent.sendEvent(self);
        end

        if self.alignmentGuide ~= nil and self.raisableElement ~= nil and self.adjustHeights ~= nil then
            if self.alignmentGuide ~= nil and self.raisableElement ~= nil and self.adjustHeights ~= nil then

                -- Change lamp height increment
                local parenthesisText = self.adjustHeights[self.activeHeight].text;
                local height = string.format("%.2f", self.adjustHeights[self.activeHeight].height);
                g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_height_changeStepSize"), parenthesisText, height), InputBinding.changeStepSize);
                
                if InputBinding.hasEvent(InputBinding.changeStepSize) and not self.chatDialogOpen then
                    self.activeHeight = self.activeHeight + 1;
                    if self.activeHeight > table.getn(self.adjustHeights) then
                        self.activeHeight = 1;
                    end
                    PlaceableLightsEvent.sendEvent(self);
                end

                -- Change lamp height
                g_currentMission:addHelpButtonText(g_i18n:getText("button_changeHeight"), InputBinding.changeHeightF1);

                -- Change lamp height up/down
                if InputBinding.hasEvent(InputBinding.changeHeightDown) and not self.chatDialogOpen then
                    local x,y,z = getTranslation(self.raisableElement);
                    local dy = self.adjustHeights[self.activeHeight].height;
                    y = Utils.clamp(y-dy, -10, 50);
                    PlaceableLightsManager.currentGhostHeight = y;
                    setTranslation(self.raisableElement, x,y,z);
                    PlaceableLightsEvent.sendEvent(self);
                elseif InputBinding.hasEvent(InputBinding.changeHeightUp) and not self.chatDialogOpen then
                    local x,y,z = getTranslation(self.raisableElement);
                    local dy = self.adjustHeights[self.activeHeight].height;
                    y = Utils.clamp(y+dy, -10, 50)
                    PlaceableLightsManager.currentGhostHeight = y;
                    setTranslation(self.raisableElement, x,y,z);
                    PlaceableLightsEvent.sendEvent(self);
                end
            end
	    end

        if self.lightColors ~= nil then

            -- Change lamp color
        	if self.activeLightColor ~= nil then
		    	if self.lightColors ~= nil and self.lightColors[self.activeLightColor] ~= nil then
    		    	local text = Utils.getNoNil(self.lightColors[self.activeLightColor].text, "ERROR");
            		g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_changeColor"), text), InputBinding.changeLightColor);
    				if InputBinding.hasEvent(InputBinding.changeLightColor) and not self.chatDialogOpen then
						self.activeLightColor = self.activeLightColor + 1;
					    if self.activeLightColor > #(self.lightColors) then
					        self.activeLightColor = 1;
					    end
			            self:setLightColor();
                        PlaceableLightsEvent.sendEvent(self);
			        end
			    end
			end

            -- Change lamp brightness
            if self.currentBrightness ~= nil then
	            local minLevel, maxLevel = 1, 50;
	            g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_changeBrightness"), Utils.getNoNil(self.currentBrightness, 0)), InputBinding.changeBrightnessF1);
	            if InputBinding.hasEvent(InputBinding.changeBrightnessUp) and not self.chatDialogOpen then
                    self.currentBrightness = Utils.clamp(self.currentBrightness + 1, minLevel, maxLevel)
	                for _,light in pairs(self.lightColors) do
	                    setLightRange(light.lightSource, self.currentBrightness);
	                end
	                self:activateTimer();
                    PlaceableLightsEvent.sendEvent(self);
	            elseif InputBinding.hasEvent(InputBinding.changeBrightnessDown) and not self.chatDialogOpen then
                    self.currentBrightness = Utils.clamp(self.currentBrightness - 1, minLevel, maxLevel)
	                for _,light in pairs(self.lightColors) do
	                    setLightRange(light.lightSource, self.currentBrightness);
	                end
	                self:activateTimer();
                    PlaceableLightsEvent.sendEvent(self);
	            end
	        end
        end
    end
end;

function PlaceableLights:PlayerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if (g_currentMission.controlPlayer and g_currentMission.player and otherId == g_currentMission.player.rootNode) then
	    if onEnter then
	        self.playersInTrigger = true;
	    elseif onLeave then
	        self.playersInTrigger = false;
	    end
    end
end


-- LOAD/SAVE
function PlaceableLights:getSaveAttributesAndNodes(nodeIdent)
    local attributes, nodes = PlaceableLights:superClass().getSaveAttributesAndNodes(self, nodeIdent);
    nodes = nodes..nodeIdent..	"<lightData currentLightState=\""..self.currentLightState..
			    					"\" activeLightColor=\""..self.activeLightColor..
			                        "\" currentBrightness=\""..self.currentBrightness

    if self.raisableElement ~= nil and self.activeHeight ~= nil then
    	local x,y,z = getTranslation(self.raisableElement);
    	nodes = nodes..			"\" activeHeight=\""..self.activeHeight..
								"\" height=\""..x.." "..y.." "..z
    end

    nodes = nodes..             "\"/>"

    return attributes, nodes;
end;

function PlaceableLights:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, key.."#position"));
    local xRot,yRot,zRot = Utils.getVectorFromString(getXMLString(xmlFile, key.."#rotation"));
    if x == nil or y == nil or z == nil or xRot == nil or yRot == nil or zRot == nil then
        return false;
    end;
    local xmlFilename = getXMLString(xmlFile, key.."#filename");
    if xmlFilename == nil then
        return false;
    end;
    xmlFilename = Utils.convertFromNetworkFilename(xmlFilename);
    
    local lightState = getXMLInt(xmlFile, key..".lightData(0)#currentLightState");
    local lightColor = getXMLInt(xmlFile, key..".lightData(0)#activeLightColor");
    local brightness = getXMLInt(xmlFile, key..".lightData(0)#currentBrightness");
    local activeHeight = getXMLInt(xmlFile, key..".lightData(0)#activeHeight");
    local xRaised, yRaised, zRaised = Utils.getVectorFromString(getXMLString(xmlFile, key..".lightData(0)#height"))

    if self:load(xmlFilename, x,y,z, xRot, yRot, zRot, false, false) then
        self.age = Utils.getNoNil(getXMLFloat(xmlFile, key.."#age"), 0);
        self.price = Utils.getNoNil(getXMLInt(xmlFile, key.."#price"), self.price);
        self.isLoadedFromSavegame = true;
        self.currentLightState = Utils.getNoNil(lightState, self.currentLightState);
        self.activeLightColor = Utils.getNoNil(lightColor, self.activeLightColor);
        self.currentBrightness = Utils.getNoNil(brightness, self.currentBrightness);
        self.activeHeight = activeHeight; -- Can be nil, for lights without height adjustment
        if self.raisableElement ~= nil then
        	setTranslation(self.raisableElement, xRaised, yRaised, zRaised);
        end
        self:finalizePlacement();

        return true;
    else
        return false;
    end;
end;

function PlaceableLights:readStream(streamId, connection)
	PlaceableLights:superClass().readStream(self, streamId, connection);
    
    if connection:getIsServer() then
	    self.currentLightState = streamReadInt8(streamId)
	    self.activeLightColor = streamReadInt8(streamId)
	    self.currentBrightness = streamReadInt8(streamId)

	    local hasRaisable = streamReadBool(streamId);

	    if hasRaisable then
		    self.activeHeight = streamReadInt8(streamId)

		    local x,y,z;
		    x = streamReadFloat32(streamId)
		    y = streamReadFloat32(streamId)
		    z = streamReadFloat32(streamId)
		    if self.raisableElement ~= nil and x~=nil and y~=nil and z~=nil then
		    	setTranslation(self.raisableElement, x,y,z);
		    end
		end
	end
end

function PlaceableLights:writeStream(streamId, connection)
    PlaceableLights:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
	    streamWriteInt8(streamId, self.currentLightState);
	    streamWriteInt8(streamId, self.activeLightColor);
	    streamWriteInt8(streamId, self.currentBrightness);

	    local hasRaisable = (self.activeHeight ~= nil and self.raisableElement ~= nil);
	    streamWriteBool(streamId, hasRaisable)

	    if hasRaisable then
		    streamWriteInt8(streamId, self.activeHeight);

		    local x,y,z = getTranslation(self.raisableElement)
		    streamWriteFloat32(streamId, x)
		    streamWriteFloat32(streamId, y)
		    streamWriteFloat32(streamId, z)
		end
	end
end

function PlaceableLightsManager:deleteMap()end;
function PlaceableLightsManager:mouseEvent(posX, posY, isDown, isUp, button)end;
function PlaceableLightsManager:keyEvent(unicode, sym, modifier, isDown)end;
function PlaceableLightsManager:update(dt)end;
function PlaceableLightsManager:draw()end;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Events

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
    self.activeHeight = lamp.activeHeight

    if lamp.raisableElement ~= nil then
        self.x, self.y, self.z = getTranslation(lamp.raisableElement);
    end

    return self;
end

function PlaceableLightsEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.lamp));
    
    streamWriteInt8(streamId, self.currentLightState);
    streamWriteInt8(streamId, self.activeLightColor);
    streamWriteInt8(streamId, self.currentBrightness);
    streamWriteInt8(streamId, self.activeHeight);

    streamWriteFloat32(streamId, self.x)
    streamWriteFloat32(streamId, self.y)
    streamWriteFloat32(streamId, self.z)
end

function PlaceableLightsEvent:readStream(streamId, connection)
    self.lamp = networkGetObject(streamReadInt32(streamId));

    self.currentLightState = streamReadInt8(streamId)
    self.activeLightColor = streamReadInt8(streamId)
    self.currentBrightness = streamReadInt8(streamId)
    self.activeHeight = streamReadInt8(streamId)

    self.x = streamReadFloat32(streamId)
    self.y = streamReadFloat32(streamId)
    self.z = streamReadFloat32(streamId)
    self:run(connection);
end

function PlaceableLightsEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.lamp);
    end
    if self.lamp ~= nil then
        self.lamp:setLightState();
        self.lamp:setLightColor();
        if self.lamp.lightColors ~= nil then
            for _,light in pairs(self.lamp.lightColors) do
                setLightRange(light.lightSource, self.lamp.currentBrightness)
            end
        end
        setTranslation(self.lamp.raisableElement, self.x,self.y,self.z);
    end
end

function PlaceableLightsEvent.sendEvent(lamp)
    if g_server ~= nil then 
        g_server:broadcastEvent(PlaceableLightsEvent:new(lamp), nil, nil, lamp);
    else
        g_client:getServerConnection():sendEvent(PlaceableLightsEvent:new(lamp));
    end;
end