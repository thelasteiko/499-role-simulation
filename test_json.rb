#!/usr/bin/env ruby

require 'json'

role_data = JSON.parse(File.read('roles.json'))
puts role_data
start_data = JSON.parse(File.read('start.json'))
puts start_data
obj = JSON.parse(File.read('pref.json'))
puts obj

roles = start_data["roles"] #integer array
    for i in 0...roles.length
      if roles[i] > 0 #number of agents in role
        #TODO so this is wonky...
        q = [start_data["qualified"][0][i],
              start_data["qualified"][1][i],
              start_data["qualified"][2][i]]
        r = role_data["roles"][i] #name of the role
        o = role_data["offices"][(i/4).to_i] #name of the office
        d = role_data[o][r] #data for the role
        t = 0 #proficiency level
        for j in 0...roles[i] #for the number of agents to be added
          #create agent
          a = nil
          if t >= q.length #got past all the proficiency levels
            puts "0 Create agent #{r}:#{roles[i]}"
          elsif q[t] == 0 #the current level has been satisfied
            t += 1
            #check the next level
            if t >= q.length #reached the end
              puts "1 Create agent #{r}:#{roles[i]}"
            elsif q[t] > 0 #next level has qualified agents
              puts "2 Create agent #{r}:#{roles[i]}"
              q[t] -= 1
            end
          else #the current level needs agents
            puts "3 Create agent #{r}:#{roles[i]}"
            q[t] -= 1
          end
          #puts "4 Create agent #{r}:#{roles[i]}" if a == nil #just in case
          #add agent to unit
          puts "Add agent #{o}:#{r}:#{roles[i]}:#{t}"
        end
      end
    end