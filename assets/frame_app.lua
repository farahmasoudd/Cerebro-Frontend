local data = require('data.min')
local battery = require('battery.min')
local camera = require('camera.min')
local code = require('code.min')
local plain_text = require('plain_text.min')

-- Phone to Frame flags
CAPTURE_SETTINGS_MSG = 0x0d
AUTO_EXP_SETTINGS_MSG = 0x0e
MANUAL_EXP_SETTINGS_MSG = 0x0f
TEXT_MSG = 0x0a
TAP_SUBS_MSG = 0x10
START_AUDIO_MSG = 0x30
STOP_AUDIO_MSG = 0x31

-- Frame to Phone flags
TAP_MSG = 0x09
AUDIO_DATA_NON_FINAL_MSG = 0x05
AUDIO_DATA_FINAL_MSG = 0x06

-- register the message parsers so they are automatically called when matching data comes in
data.parsers[CAPTURE_SETTINGS_MSG] = camera.parse_capture_settings
data.parsers[AUTO_EXP_SETTINGS_MSG] = camera.parse_auto_exp_settings
data.parsers[MANUAL_EXP_SETTINGS_MSG] = camera.parse_manual_exp_settings
data.parsers[TEXT_MSG] = plain_text.parse_plain_text
data.parsers[TAP_SUBS_MSG] = code.parse_code
data.parsers[START_AUDIO_MSG] = code.parse_code
data.parsers[STOP_AUDIO_MSG] = code.parse_code

function handle_tap()
    rc, err = pcall(frame.bluetooth.send, string.char(TAP_MSG))
    
    if rc == false then
        -- send the error back on the stdout stream
        print(err)
    end
end

-- draw the current text on the display
function print_text()
    local i = 0
    for line in data.app_data[TEXT_MSG].string:gmatch("([^\n]*)\n?") do
        if line ~= "" then
            frame.display.text(line, 1, i * 60 + 1)
            i = i + 1
        end
    end
end

function clear_display()
    frame.display.text(" ", 1, 1)
    frame.display.show()
    frame.sleep(0.04)
end

function show_flash()
    frame.display.bitmap(241, 191, 160, 2, 0, string.rep("\xFF", 400))
    frame.display.bitmap(311, 121, 20, 2, 0, string.rep("\xFF", 400))
    frame.display.show()
    frame.sleep(0.04)
end

-- Main app loop
function app_loop()
    clear_display()
    local last_batt_update = 0
    local streaming = false
    local audio_data = ''
    local mtu = frame.bluetooth.max_length()
    local audio_timeout = 0
    local max_audio_timeout = 300 -- 30 seconds at 0.1s intervals
    
    -- data buffer needs to be even for reading from microphone
    if mtu % 2 == 1 then mtu = mtu - 1 end

    while true do
        rc, err = pcall(
            function()
                -- process any raw data items, if ready
                local items_ready = data.process_raw_items()

                if items_ready > 0 then

                    -- Handle camera capture
                    if (data.app_data[CAPTURE_SETTINGS_MSG] ~= nil) then
                        -- visual indicator of capture and send
                        show_flash()
                        rc, err = pcall(camera.capture_and_send, data.app_data[CAPTURE_SETTINGS_MSG])
                        clear_display()

                        if rc == false then
                            print(err)
                        end

                        data.app_data[CAPTURE_SETTINGS_MSG] = nil
                    end

                    -- Handle camera exposure settings
                    if (data.app_data[AUTO_EXP_SETTINGS_MSG] ~= nil) then
                        rc, err = pcall(camera.set_auto_exp_settings, data.app_data[AUTO_EXP_SETTINGS_MSG])

                        if rc == false then
                            print(err)
                        end

                        data.app_data[AUTO_EXP_SETTINGS_MSG] = nil
                    end

                    if (data.app_data[MANUAL_EXP_SETTINGS_MSG] ~= nil) then
                        rc, err = pcall(camera.set_manual_exp_settings, data.app_data[MANUAL_EXP_SETTINGS_MSG])

                        if rc == false then
                            print(err)
                        end

                        data.app_data[MANUAL_EXP_SETTINGS_MSG] = nil
                    end

                    -- Handle text display
                    if (data.app_data[TEXT_MSG] ~= nil and data.app_data[TEXT_MSG].string ~= nil) then
                        clear_display()
                        print_text()
                        frame.display.show()
                        data.app_data[TEXT_MSG] = nil
                    end

                    -- Handle tap subscription
                    if (data.app_data[TAP_SUBS_MSG] ~= nil) then
                        if data.app_data[TAP_SUBS_MSG].value == 1 then
                            -- start subscription to tap events
                            print('subscribing for taps')
                            frame.imu.tap_callback(handle_tap)
                        else
                            -- cancel subscription to tap events
                            print('cancel subscription for taps')
                            frame.imu.tap_callback(nil)
                        end
                        data.app_data[TAP_SUBS_MSG] = nil
                    end

                    -- Handle audio recording start
                    if (data.app_data[START_AUDIO_MSG] ~= nil) then
                        audio_data = ''
                        audio_timeout = 0
                        rc_mic, err_mic = pcall(frame.microphone.start, {sample_rate=8000, bit_depth=16})
                        if rc_mic then
                            streaming = true
                            frame.display.text("🎤 Recording", 1, 1)
                            frame.display.show()
                            print('Audio recording started')
                        else
                            print('Failed to start microphone: ' .. tostring(err_mic))
                            frame.display.text("Mic Error", 1, 1)
                            frame.display.show()
                        end
                        data.app_data[START_AUDIO_MSG] = nil
                    end

                    -- Handle audio recording stop
                    if (data.app_data[STOP_AUDIO_MSG] ~= nil) then
                        if streaming then
                            pcall(frame.microphone.stop)
                            streaming = false
                            audio_timeout = 0
                            print('Audio recording stopped manually')
                            -- Send final message
                            pcall(frame.bluetooth.send, string.char(AUDIO_DATA_FINAL_MSG))
                        end
                        clear_display()
                        data.app_data[STOP_AUDIO_MSG] = nil
                    end

                end

                -- Handle audio streaming with improved error handling
                if streaming then
                    audio_timeout = audio_timeout + 1
                    
                    -- Timeout check
                    if audio_timeout > max_audio_timeout then
                        print('Audio recording timeout')
                        pcall(frame.microphone.stop)
                        streaming = false
                        audio_timeout = 0
                        pcall(frame.bluetooth.send, string.char(AUDIO_DATA_FINAL_MSG))
                        clear_display()
                    else
                        -- Process audio data with error handling
                        for i=1,5 do  -- Reduced from 20 to 5 for better stability
                            if not streaming then break end
                            
                            local success, result = pcall(frame.microphone.read, mtu)
                            if success and result then
                                if result == '' then
                                    -- No data available, continue
                                    break
                                else
                                    audio_data = result
                                    -- Send the data
                                    local send_success = pcall(frame.bluetooth.send, string.char(AUDIO_DATA_NON_FINAL_MSG) .. audio_data)
                                    if not send_success then
                                        print('Failed to send audio data')
                                    end
                                    frame.sleep(0.0025)
                                end
                            elseif success and result == nil then
                                -- Microphone stopped, end streaming
                                pcall(frame.bluetooth.send, string.char(AUDIO_DATA_FINAL_MSG))
                                streaming = false
                                audio_timeout = 0
                                break
                            else
                                -- Error reading from microphone
                                print('Error reading microphone data')
                                pcall(frame.microphone.stop)
                                streaming = false
                                audio_timeout = 0
                                pcall(frame.bluetooth.send, string.char(AUDIO_DATA_FINAL_MSG))
                                break
                            end
                        end
                    end
                end

                -- periodic battery level updates, 120s for a camera app
                last_batt_update = battery.send_batt_if_elapsed(last_batt_update, 120)

                -- Run auto exposure if enabled
                if camera.is_auto_exp then
                    camera.run_auto_exposure()
                end

                -- Sleep less when streaming audio for better responsiveness
                if not streaming then 
                    frame.sleep(0.1) 
                else
                    frame.sleep(0.02)  -- Shorter sleep when streaming
                end
            end
        )
        
        -- Catch the break signal here and clean up the display
        if rc == false then
            -- send the error back on the stdout stream
            print('Main loop error: ' .. tostring(err))
            -- Clean up streaming state
            if streaming then
                pcall(frame.microphone.stop)
                pcall(frame.bluetooth.send, string.char(AUDIO_DATA_FINAL_MSG))
            end
            frame.display.text(" ", 1, 1)
            frame.display.show()
            frame.sleep(0.04)
            break
        end
    end
end

-- run the main app loop
app_loop()