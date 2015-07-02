-- Copyright 2015 Boundary, Inc.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local framework = require('framework.lua')
local Plugin = framework.Plugin
local DataSourcePoller = framework.DataSourcePoller
local WebRequestDataSource = framework.WebRequestDataSource
local PollerCollection = framework.PollerCollection
local url = require('url')
local notEmpty = framework.string.notEmpty
local isHttpSuccess = framework.util.isHttpSuccess
local params = framework.params
local os = require('os')
local consul_url = "http://localhost:8500/v1/health/node/" .. os.hostname() .. "?pretty=1"
local string = require('string')
local table = require('table')
local json = require('json')


-- setup plugin poller
local function createPollers(params) 
    
    local pollers = PollerCollection:new() 
    
    local options = url.parse(consul_url)
    
    options.protocol = 'http'
    options.method = "GET"
    options.meta = { source = "consul", ignoreStatusCode = false, debugEnabled = true }
    options.wait_for_end = false

    local data_source = WebRequestDataSource:new(options)

    local time_interval = tonumber(notEmpty(params.pollInterval, 1000))
    if time_interval < 500 then time_interval = time_interval * 1000 end
    
    local poller = DataSourcePoller:new(time_interval, data_source)
    
    pollers:add(poller)

    return pollers
end

local pollers = createPollers(params)

local function logFailure(str)
    process.stderr:write(str)  
end

local plugin = Plugin:new(params, pollers)

local healthcheck_result = {}

function plugin:onParseValues(body, extra)
    
    if not extra.info.ignoreStatusCode and not isHttpSuccess(extra.status_code) then
        self:emitEvent('error', ('%s Returned %d'):format(extra.info.source, extra.status_code), self.source, self.source, ('HTTP Request Returned %d instead of OK'):format(extra.status_code))
        if (extra.info.debugEnabled) then
            logFailure(extra.info.source .. ' status code: ' .. extra.status_code .. '\n')
            logFailure(extra.info.source .. ' body:\n' .. tostring(body) .. '\n')
        end
        return {}
    end
    
    local healthcheck_output_json = json.parse(body)
    local event_type = 'info'
    
    for i,healthcheck_output in next,healthcheck_output_json,nil do
        
        if healthcheck_result[healthcheck_output.CheckID] == nil or not string.find(healthcheck_result[healthcheck_output.CheckID], healthcheck_output.Status) then
            healthcheck_result[healthcheck_output.CheckID] = healthcheck_output.Status

            if string.find(healthcheck_output.Status, 'passing') then
                event_type = 'info'  
                
                if params.detailedInfo ~= nil and params.detailedInfo == true then
                    
                    local j,k = string.find(healthcheck_output.Output, " Output: {")
                    
                    if k ~= nil then -- embedded json?
                        local preformatted_healthcheck_output_json = string.sub(healthcheck_output.Output, k, -1)
                        local preformatted_healthcheck_output = json.parse(preformatted_healthcheck_output_json)
                        local temp_table = {}
                        
                        for healthcheck_key,healthcheck_value in next,preformatted_healthcheck_output,nil do
                            if healthcheck_value.message ~= nil then
                                table.insert(temp_table, healthcheck_key .. ": " .. healthcheck_value.message)
                            else
                                table.insert(temp_table, healthcheck_key .. ": passed health check")
                            end
                        end
                        
                        local healthcheck_msg = table.concat(temp_table, "\\n") -- send newline-separated list msg (formatted per event msg spec)
                        self:emitEvent(event_type, healthcheck_output.Name .. ": " .. healthcheck_output.CheckID, healthcheck_output.Node, "consul", healthcheck_msg)
                    else
                        self:emitEvent(event_type, healthcheck_output.Name .. ": " .. healthcheck_output.CheckID, healthcheck_output.Node, "consul", healthcheck_output.Output) 
                    end
                else
                    self:emitEvent(event_type, healthcheck_output.Name .. ": " .. healthcheck_output.CheckID, healthcheck_output.Node, "consul", "") -- send no msg
                end
            else
                if string.find(healthcheck_output.Status, 'warning') then
                    event_type = 'warning'
                elseif string.find(healthcheck_output.Status, 'critical') or string.find(healthcheck_output.Status, 'unknown') then
                    event_type = 'critical'
                else
                    event_type = 'error'
                end

                local j,k = string.find(healthcheck_output.Output, " Output: {")

                if k ~= nil then -- embedded json?
                    local preformatted_healthcheck_output_json = string.sub(healthcheck_output.Output, k, -1)
                    local preformatted_healthcheck_output = json.parse(preformatted_healthcheck_output_json)
                    local temp_table = {}
                    
                    for healthcheck_key,healthcheck_value in next,preformatted_healthcheck_output,nil do
                        if healthcheck_value.healthy == false then
                            if healthcheck_value.message ~= nil then
                                table.insert(temp_table, healthcheck_key .. ": " .. healthcheck_value.message)
                            else
                                table.insert(temp_table, healthcheck_key .. ": failed health check")
                            end
                        elseif params.detailedInfo ~= nil and params.detailedInfo == true then
                            if healthcheck_value.message ~= nil then
                                table.insert(temp_table, healthcheck_key .. ": " .. healthcheck_value.message)
                            else
                                table.insert(temp_table, healthcheck_key .. ": passed health check")
                            end
                        end
                    end

                    local healthcheck_msg = table.concat(temp_table, "\\n") -- send newline-separated list msg (formatted per event msg spec)
                    self:emitEvent(event_type, healthcheck_output.Name .. ": " .. healthcheck_output.CheckID, healthcheck_output.Node, "consul", healthcheck_msg)
                else -- just print what's there
                    self:emitEvent(event_type, healthcheck_output.Name .. ": " .. healthcheck_output.CheckID, healthcheck_output.Node, "consul", healthcheck_output.Output)
                end
            end
        end
    end
    
    return {}
end

plugin:run()

