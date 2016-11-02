      #both try to compromise
      #to           agent         from
      #needed +     desired +     not needed  = yes X
      #needed +     desired +     needed      = yes X
      #needed +     not desired + not needed  = yes 
      #needed +     not desired + needed      = no  X
      #not needed + desired +     not needed  = yes X
      #not needed + desired +     needed      = no  X
      #not needed + not desired + not needed  = no
      #not needed + not desired + needed      = no  X
      r0 = agent.role.role_name
      r1 = agent.desired_role
      r2 = priority_need
      #desired + needed
      if @old_resources[r1] < @@default_data["resources"][r1]
        #desired + needed + not needed
        if @old_resources[r0] >= @@default_data["resources"][r0]
          #agent role change
          r = r1
        else #desired + needed + needed
          r = r0
        end
      #desired + not needed
      else
        #desired + not needed + not needed
        if @old_resources[r0] >= @@default_data["resources"][r0]
          r = r1
        else #desired + not needed + needed
          #too bad, can't retrain to desired role
        end
      end
      if r == nil #has not chosen
        #not desired + needed
        if @old_resources[r2] < @@default_data["resources"][r2]
          #not desired + needed + not needed
          if @old_resources[r0] >= @@default_data["resources"][r0]
            r = r2
          end #not desired + needed + needed
        #not desired + not needed
        end
      end
      return nil if r == nil
      o = @@role_data["offices"][(@@role_data["roles"].index(r)/3).to_i]
      d = @@role_data[o][r]
      role = RoleProgress.new(o,r,d)
      return agent.change_role(role)