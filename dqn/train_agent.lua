--[[
Copyright (c) 2014 Google Inc.

See LICENSE file for full terms of limited license.
]]


if not dqn then
    require "initenv"
end

local cmd = torch.CmdLine()
cmd:text()
cmd:text('Train Agent in Environment:')
cmd:text()
cmd:text('Options:')

cmd:option('-framework', '', 'name of training framework')
cmd:option('-env', '', 'name of environment to use')
cmd:option('-game_path', '', 'path to environment file (ROM)')
cmd:option('-env_params', '', 'string of environment parameters')
cmd:option('-pool_frms', '',
           'string of frame pooling parameters (e.g.: size=2,type="max")')
cmd:option('-actrep', 1, 'how many times to repeat action')
cmd:option('-random_starts', 0, 'play action 0 between 1 and random_starts ' ..
           'number of times at the start of each training episode')

cmd:option('-name', '', 'filename used for saving network and training history')
cmd:option('-network', '', 'reload pretrained network')
cmd:option('-agent', '', 'name of agent file to use')
cmd:option('-agent_params', '', 'string of agent parameters')
cmd:option('-seed', 1, 'fixed input seed for repeatable experiments')
cmd:option('-saveNetworkParams', true,
           'saves the agent network in a separate file')
cmd:option('-prog_freq', 5*10^3, 'frequency of progress output')
cmd:option('-save_freq', 5*10^4, 'the model is saved every save_freq steps')
cmd:option('-eval_freq', 10^4, 'frequency of greedy evaluation')
cmd:option('-save_versions', 0, '')

cmd:option('-steps', 10^5, 'number of training steps to perform')
cmd:option('-eval_steps', 10^5, 'number of evaluation steps')

cmd:option('-verbose', 2,
           'the higher the level, the more information is printed to screen')
cmd:option('-threads', 1, 'number of BLAS threads')
cmd:option('-gpu', -1, 'gpu flag')
cmd:option('-display', 0, '1 to enable display')
cmd:option('-store_src', "", 'Path to store the trained network')
cmd:option('-gpu_type', 1, '1->nvidia | 2->amd')

cmd:text()


local opt = cmd:parse(arg)

--- General setup.
local game_env, game_actions, agent, opt = setup(opt)

-- override print to always flush the output
local old_print = print
local print = function(...)
    old_print(...)
    io.flush()
end

local learn_start = agent.learn_start
local start_time = sys.clock()
local reward_counts = {}
local episode_counts = {}
local time_history = {}
local v_history = {}
local qmax_history = {}
local td_history = {}
local reward_history = {}
local step = 0
time_history[1] = 0

local total_reward
local nrewards
local nepisodes
local episode_reward

local date = os.date("%m%d")

local screen, reward, terminal = game_env:getState()

-- Fill stored data from the last  training
local msg, err = pcall(require, opt.agent_params.network)
if not msg then
    print("Loading training parameters", opt.agent_params.network)
    -- try to load saved agent
    local err_msg, exp = pcall(torch.load, opt.agent_params.network)
    if not err_msg then
        error("Could not find network file ")
    end
    if exp.reward_history then
      reward_history = exp.reward_history
    end
    if exp.reward_counts then
      reward_counts = exp.reward_counts
    end
    if exp.episode_counts then
      episode_counts = exp.episode_counts
    end
    if exp.time_history then
      time_history = exp.time_history
    end
    if exp.v_history then
      v_history = exp.v_history
    end
    if exp.td_history then
      td_history = exp.td_history
    end
    if exp.qmax_history then
      qmax_history = exp.qmax_history
    end
end

print ("Num Actions: ", #game_actions)
for i,line in ipairs(game_actions) do
	print(i, line)
end


print("Iteration ..", step)
while step < opt.steps do
    step = step + 1
    local action_index = agent:perceive(reward, screen, terminal)

    -- game over? get next game!
    if not terminal then
        screen, reward, terminal = game_env:step(game_actions[action_index], true)
    else
        if opt.random_starts > 0 then
            screen, reward, terminal = game_env:nextRandomGame()
        else
            screen, reward, terminal = game_env:newGame()
        end
    end


    -- Print info each opt.prog_freq steps
    if step % opt.prog_freq == 0 then
        assert(step==agent.numSteps, 'trainer step: ' .. step ..
                ' & agent.numSteps: ' .. agent.numSteps)
        print("Steps: ", step, "\t", os.date("%m/%d/%y %X"))
        agent:report()
        collectgarbage()
    end

    if step%1000 == 0 then collectgarbage() end

    -- Evaluate the system each opt.eval_freq steps
    -- Create a new game and iterate opt.eval_steps
    if step % opt.eval_freq == 0 and step > learn_start then
print("- Evaluating", "\t", os.date("%m/%d/%y %X"))
        screen, reward, terminal = game_env:newGame()

        total_reward = 0
        nrewards = 0
        nepisodes = 0
        episode_reward = 0

        local eval_time = sys.clock()
        for estep=1,opt.eval_steps do
            local action_index = agent:perceive(reward, screen, terminal, true, 0.05)

            -- Play game in test mode (episodes don't end when losing a life)
            screen, reward, terminal = game_env:step(game_actions[action_index])

            if estep%1000 == 0 then collectgarbage() end

            -- record every reward
            episode_reward = episode_reward + reward
            if reward ~= 0 then
               nrewards = nrewards + 1
            end

            if terminal then
                total_reward = total_reward + episode_reward
                episode_reward = 0
                nepisodes = nepisodes + 1
                screen, reward, terminal = game_env:nextRandomGame()
            end
        end
        eval_time = sys.clock() - eval_time
        start_time = start_time + eval_time
        agent:compute_validation_statistics()
        local ind = #reward_history+1
        total_reward = total_reward/math.max(1, nepisodes)

--[[
        if #reward_history == 0 or total_reward > torch.Tensor(reward_history):max() then
            agent.best_network = agent.network:clone()
        end
]]
        if agent.v_avg then
            v_history[ind] = agent.v_avg
            td_history[ind] = agent.tderr_avg
            qmax_history[ind] = agent.q_max
        end
        print("V", v_history[ind], "TD error", td_history[ind], "Qmax", qmax_history[ind])

        reward_history[ind] = total_reward
        reward_counts[ind] = nrewards
        episode_counts[ind] = nepisodes

        time_history[ind+1] = sys.clock() - start_time

        local time_dif = time_history[ind+1] - time_history[ind]

        local training_rate = opt.actrep*opt.eval_freq/time_dif

        print(string.format(
            '\nSteps: %d (frames: %d), reward: %.2f, epsilon: %.2f, lr: %G, ' ..
            'training time: %ds, training rate: %dfps, testing time: %ds, ' ..
            'testing rate: %dfps,  num. ep.: %d,  num. rewards: %d',
            step, step*opt.actrep, total_reward, agent.ep, agent.lr, time_dif,
            training_rate, eval_time, opt.actrep*opt.eval_steps/eval_time,
            nepisodes, nrewards))
    end

    -- Store the current network each opt.save_freq or when the training has ended
    if step % opt.save_freq == 0 or step == opt.steps then
print("- Saving", "\t", os.date("%m/%d/%y %X"))

        local filename = opt.name

        if opt.saveNetworkParams then
            --[[
            local nets = {network=w:clone():float()}
            torch.save(opt.store_src .. filename .. "_" .. date ..'.params.t7', { nets = nets })
            lightModel = agent.network:clone('weight','bias','running_mean','running_std')
            torch.save(opt.store_src .. filename .. "_" .. date ..'.paramsLightModel.t7', { model = lightModel })
            ]]

            -- Save the comlete network and also only the convolutional part
            torch.save(opt.store_src .. filename .. "_" .. date ..'.model.t7', { model = agent.network, network = agent.network:get(2) })
            print('Saved:', opt.store_src .. filename .. "_" .. date ..'.model.t7', "\t", os.date("%m/%d/%y %X"))
        else
            local s, a, r, s2, term = agent.valid_s, agent.valid_a, agent.valid_r,
                agent.valid_s2, agent.valid_term
            agent.valid_s, agent.valid_a, agent.valid_r, agent.valid_s2,
                agent.valid_term = nil, nil, nil, nil, nil, nil, nil
            local w, dw, g, g2, delta, delta2, deltas, tmp = agent.w, agent.dw,
                agent.g, agent.g2, agent.delta, agent.delta2, agent.deltas, agent.tmp
            agent.w, agent.dw, agent.g, agent.g2, agent.delta, agent.delta2,
                agent.deltas, agent.tmp = nil, nil, nil, nil, nil, nil, nil, nil

            if opt.save_versions > 0 then
                filename = opt.store_src .. filename .. "_" .. math.floor(step / opt.save_versions) .. "_" .. date
            end
            filename = filename
            torch.save(opt.store_src .. filename .. "_" .. date .. ".t7", {agent = agent,
                                    model = agent.network,
                                    best_model = agent.best_network,
                                    reward_history = reward_history,
                                    reward_counts = reward_counts,
                                    episode_counts = episode_counts,
                                    time_history = time_history,
                                    v_history = v_history,
                                    td_history = td_history,
                                    qmax_history = qmax_history,
                                    arguments=opt})



            agent.valid_s, agent.valid_a, agent.valid_r, agent.valid_s2,
                agent.valid_term = s, a, r, s2, term
            agent.w, agent.dw, agent.g, agent.g2, agent.delta, agent.delta2,
                agent.deltas, agent.tmp = w, dw, g, g2, delta, delta2, deltas, tmp
            print('Saved:', filename .. '.t7', "\t", os.date("%m/%d/%y %X"))
        end

        io.flush()
        collectgarbage()
    end
end
