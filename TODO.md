1. ~~钝器砍舌~~
2. c5m5 magnum and tank
3. 尸潮
    * survivor_limit (救援关刷药问题，出门后限制)
    * 改 versus2coop
    * left4dhooks 控制 mob 数量 (!TODO)
        >/**  
        >\* @brief Called whenever CDirector::OnMobRushStart(void) is invoked  
        >\* @remarks called on random hordes, mini and >finale hordes, and boomer hordes, causes >Zombies to attack  
        >\*			Not called on "z_spawn mob", hook the console command and check arguments >to catch plugin >mobs  
        >\*			This function is used to reset the Director's natural horde timer.  
        >\*  
        >\* @return				Plugin_Handled to block, Plugin_Continue otherwise  
        >\*/  
        >forward Action L4D_OnMobRushStart();  
  
        >/**  
        >\* @brief Called whenever ZombieManager::SpawnMob(int) is invoked  
        >\* @remarks called on natural hordes & z_spawn mob, increases Zombie Spawn  
        >\*			Queue, triggers player OnMobSpawned (vocalizations), sets horde  
        >\*			direction, and plays horde music.  
        >\*  
        >\* @param amount		Amount of Zombies to add to Queue  
        >\*  
        >\* @return				Plugin_Handled to block, Plugin_Changed to use overwritten values from plugin, Plugin_Continue otherwise  
        >\*/  
        >forward Action L4D_OnSpawnMob(int &amount);  

4. Stripper