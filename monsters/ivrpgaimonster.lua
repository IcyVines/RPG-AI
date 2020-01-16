function initAI()
  self.rpg_enemyProjectiles = {}
  self.rpg_actionCooldown = 0
  self.rpg_jumpDodgeTimer = 0
  self.rpg_dashTimer = 0
  self.rpg_dashDirection = {}
  self.rpg_excludeList = root.assetJson("/ivrpgExcludeMonsterAI.config")
  self.rpg_specialList = root.assetJson("/ivrpgMonsterAI.config")
  self.rpg_specialAction = self.rpg_specialList[self.rpg_enemyType] or "default"
  if not self.rpg_excludeList[self.rpg_enemyType] then script.setUpdateDelta(1) end
end

function updateAI(dt)
  --Advanced AI - Added for Corrupted and Demonic enemies.
  --[[
  if #self.rpg_players > 0 then
    for _,id in ipairs(self.rpg_players) do
      local handPrimary = ivrpgBuildItemConfig(id, "primary")
      local handAlt = ivrpgBuildItemConfig(id, "alt")
      if handPrimary and not root.itemHasTag(handPrimary.config.itemName, "melee") then
        if handAlt then
          if not root.itemHasTag(handAlt.config.itemName, "melee") then
            monster.flyTo(world.entityPosition(id))
          end
        else
          monster.flyTo(world.entityPosition(id))
        end
      end
    end
  end
  --]]

  if self.rpg_excludeList[self.rpg_enemyType] then return end
  --Dodge Incoming Projectiles
  local facingDirection = mcontroller.facingDirection()
  if self.rpg_jumpDodgeTimer > 0 then
    if self.rpg_jumpDodgeTimer == 0.5 then
      mcontroller.controlJump()
    end
    self.rpg_jumpDodgeTimer = math.max(0, self.rpg_jumpDodgeTimer - dt)
    if not mcontroller.groundMovement() then mcontroller.controlApproachXVelocity(facingDirection * 25, 500) end
    if self.rpg_jumpDodgeTimer == 0 then
      self.rpg_actionCooldown = 3
    end
  elseif self.rpg_dashTimer > 0 then
    self.rpg_dashTimer = math.max(0, self.rpg_dashTimer - dt)
    if world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), vec2.mul(self.rpg_dashDirection, 5)), {"Block", "Slippery", "Dynamic"}) then
      self.rpg_dashDirection = vec2.mul(self.rpg_dashDirection, -1)
    end
    mcontroller.controlApproachVelocity(vec2.mul(self.rpg_dashDirection, 50), (mcontroller.liquidMovement() and 2 or 1) * 500)
    if self.rpg_dashTimer == 0 then
      if self.rpg_specialAction == "stop" then mcontroller.setVelocity({0,0}) end
      self.rpg_actionCooldown = 3
    end
  elseif self.rpg_actionCooldown == 0 then
    dodgeProjectiles()
  end

  self.rpg_actionCooldown = math.max(self.rpg_actionCooldown - dt, 0)
  purgeEnemyProjectiles()

end

--[[
function getProjectilesFromList(list)
  local projectiles = {}
  for _,id in ipairs(list) do
    if world.entityExists(id) and world.entitySpecies(id) then
      table.insert(self.rpg_players, id)
    else
      table.insert(projectiles, id)
    end
  end
  return projectiles
end
--]]

function dodgeProjectiles()
  local facingDirection = mcontroller.facingDirection()
  -- Rectangle Search - Obsolete
  -- {mcontroller.xPosition() - (facingDirection == -1 and 10 or 0), mcontroller.yPosition() - 10}, {mcontroller.xPosition() - (facingDirection == -1 and 0 or 10), mcontroller.yPosition() + 10}
  local enemyProjectiles = world.entityQuery(mcontroller.position(), 30, {
    includedTypes = {"projectile"}
  })
  --local enemyProjectiles = getProjectilesFromList(enemies)
  if enemyProjectiles and #enemyProjectiles > 0 then
    for _,pId in ipairs(enemyProjectiles) do
      local pPos = world.entityPosition(pId)
      local distance = world.distance(pPos, mcontroller.position())
      if world.entityCanDamage(pId, self.rpg_Id) and operate((facingDirection == -1 and "<" or ">"), distance[1], 0) and not world.lineTileCollision(mcontroller.position(), pPos, {"Block", "Slippery", "Dynamic"}) then
        local pVel = nil
        if self.rpg_enemyProjectiles[pId] then
          pVel = world.distance(pPos, self.rpg_enemyProjectiles[pId])
        end
        self.rpg_enemyProjectiles[pId] = pPos
        --if pVel
        if pVel and ((pVel[1] < 0 and distance[1] > 0) or (pVel[1] > 0 and distance[1] < 0)) then
          local predictedPos = util.predictedPosition(mcontroller.position(), pPos, mcontroller.velocity(), vec2.mag(pVel))
          --[[
          local predicted = "Predicted: " .. sb.printJson(predictedPos)
          local positions = "Enemy Pos: " .. sb.printJson(mcontroller.position()) .. ", Projectile Pos: " .. sb.printJson(pPos)
          local velocity = "Projectile Vel: " .. sb.printJson(pVel)
          sb.logInfo(predicted .. " - " .. positions .. " - " .. velocity .. "\n")
          --]]
          if not vec2.eq(predictedPos, mcontroller.position()) then
            if mcontroller.groundMovement() and self.rpg_specialAction ~= "nojump" then
              self.rpg_jumpDodgeTimer = 0.5
            elseif ((pVel[2] < 0 and distance[2] > 0) or (pVel[2] > 0 and distance[2] < 0)) then
              self.rpg_dashTimer = 0.1
              self.rpg_dashDirection = vec2.norm(vec2.rotate(pVel, math.pi/2))
            end
          end
        end
      end
    end
  end
end

function purgeEnemyProjectiles()
  for pId,pos in pairs(self.rpg_enemyProjectiles) do
    if not world.entityExists(pId) then
      self.rpg_enemyProjectiles[pId] = nil
    end
  end
end
