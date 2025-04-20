#===============================================================================
# Champions2D Rental Team Plugin for Pokemon Essentials v21.1
#===============================================================================

module CHAMPIONS2D
  OT_NAME = "CHAMPIONS2D"  # The OT name for rental Pokemon
  RENTAL_LEVEL = 100       # Level for rental Pokemon
  GUARANTEED_IVS = 31      # IVs for rental Pokemon (perfect)
  
  # Minimum base stat requirements for "strong" Pokémon
  MIN_BST = 500           # Minimum Base Stat Total for selection
  MIN_OFFENSIVE = 100     # Minimum offensive stat (Attack or Sp. Attack)
  MIN_SPEED = 80          # Minimum Speed stat for consideration
  LEGENDARY_CHANCE = 7   # Percent chance (0-100) to include legendary Pokémon
  
  # Add EV distribution patterns
  EV_DISTRIBUTIONS = [
    { :HP => 252, :ATTACK => 252, :SPEED => 4 },     # Physical Sweeper
    { :HP => 252, :SPECIAL_ATTACK => 252, :SPEED => 4 }, # Special Sweeper
    { :HP => 252, :DEFENSE => 252, :SPECIAL_DEFENSE => 4 }, # Physical Wall
    { :HP => 252, :SPECIAL_DEFENSE => 252, :DEFENSE => 4 }, # Special Wall
    { :HP => 252, :DEFENSE => 128, :SPECIAL_DEFENSE => 128 }, # Mixed Wall
    { :ATTACK => 252, :SPEED => 252, :HP => 4 },     # Fast Physical Attacker
    { :SPECIAL_ATTACK => 252, :SPEED => 252, :HP => 4 }, # Fast Special Attacker
    { :ATTACK => 252, :DEFENSE => 252, :HP => 4 },   # Bulky Attacker
    { :SPECIAL_ATTACK => 252, :SPECIAL_DEFENSE => 252, :HP => 4 }, # Bulky Special Attacker
    { :HP => 252, :SPEED => 252, :DEFENSE => 4 }     # Fast Tank
  ]
end

#===============================================================================
# Rental Team Generator
#===============================================================================

# This class handles the rental team functionality
class Champions2DRentalTeam
  # Set up competitive movesets based on Pokémon's stats and typing
  def self.setup_competitive_moveset(pkmn)
    # Clear existing moves
    pkmn.moves.clear
    
    # Get attacking stats
    physical_power = pkmn.attack
    special_power = pkmn.spatk
    
    # Determine if the Pokémon is better as physical or special attacker
    physical_attacker = physical_power > special_power
    
    # Get primary and secondary types using newer API
    types = pkmn.types
    
    # Get a list of all available moves
    available_moves = []
    
    # Add moves from the move list
    if pkmn.getMoveList
      pkmn.getMoveList.each { |m| available_moves.push(m[1]) }
    end
    
    # Remove duplicates
    available_moves.uniq!
    
    # Initialize move categories
    stab_attacks = []
    coverage_attacks = []
    status_moves = []
    setup_moves = []
    recovery_moves = []
    priority_moves = []
    
    # Categorize all available moves
    available_moves.each do |move_id|
      next unless GameData::Move.exists?(move_id)
      move_data = GameData::Move.get(move_id)
      
      # Skip moves with less than 10 PP total or low accuracy (less than 80) unless they are status moves
      next if move_data.total_pp < 10
      next if move_data.accuracy > 0 && move_data.accuracy < 80 && move_data.category != 2 # Skip inaccurate attacks
      
      # Skip low power moves unless they have secondary effects or are not attacking moves
      if move_data.category != 2 && move_data.power < 60
        # Keep moves with additional effects or special properties
        next unless move_data.effect_chance > 0 || move_data.priority > 0
      end
      
      # Categorize move based on type and properties
      if move_data.category == 2 # Status move
        if [:SWORDSDANCE, :NASTYPLOT, :DRAGONDANCE, :CALMMIND, :SHELLSMASH, :GROWTH, 
            :WORKUP, :TAILGLOW, :QUIVERDANCE, :COIL].include?(move_id)
          setup_moves.push(move_id) # Setup/stat boosting moves
        elsif [:RECOVER, :ROOST, :SLACKOFF, :MILKDRINK, :MOONLIGHT, :MORNINGSUN, 
               :SYNTHESIS, :WISH, :HEALORDER, :SHOREUP, :JUNGLEHEALING].include?(move_id)
          recovery_moves.push(move_id) # Recovery moves
        elsif ![:SPLASH, :CELEBRATE, :HOLDHANDS, :HAPPYHOUR].include?(move_id)
          status_moves.push(move_id) # Other useful status moves, excluding purely cosmetic moves
        end
      elsif move_data.priority > 0
        priority_moves.push(move_id) # Priority attacks
      elsif types.include?(move_data.type)
        # STAB moves - match the preferred attacking style
        if (physical_attacker && move_data.category == 0) || (!physical_attacker && move_data.category == 1)
          stab_attacks.push(move_id)
        end
      else
        # Coverage moves - match the preferred attacking style
        if (physical_attacker && move_data.category == 0) || (!physical_attacker && move_data.category == 1)
          coverage_attacks.push(move_id)
        end
      end
    end
    
    # Sort attacks by power
    stab_attacks.sort_by! { |move_id| -GameData::Move.get(move_id).power }
    coverage_attacks.sort_by! { |move_id| -GameData::Move.get(move_id).power }
    
    # Begin move selection
    selected_moves = []
    
    # 1. Consider a setup move if the Pokémon has good stats (BST > 500)
    bst = pkmn.attack + pkmn.defense + pkmn.spatk + pkmn.spdef + pkmn.speed + pkmn.totalhp
    if bst > 500 && !setup_moves.empty? && rand(10) > 4 # 60% chance for strong Pokémon
      # Physical attackers get physical setup, special get special setup
      setup_move = setup_moves.find do |move_id|
        move_data = GameData::Move.get(move_id)
        if physical_attacker
          [:ATTACK].any? { |stat| move_data.respond_to?(:statUp) && move_data.statUp && move_data.statUp.include?(stat) }
        else
          [:SPECIAL_ATTACK].any? { |stat| move_data.respond_to?(:statUp) && move_data.statUp && move_data.statUp.include?(stat) }
        end
      end
      
      selected_moves.push(setup_move) if setup_move
    end
    
    # 2. Add recovery move if available and the Pokémon is bulky
    if !recovery_moves.empty? && (pkmn.defense > 80 || pkmn.spdef > 80) && rand(10) > 3
      selected_moves.push(recovery_moves.sample)
    end
    
    # 3. Add priority move if available
    if !priority_moves.empty? && pkmn.speed < 80 && selected_moves.length < 4
      selected_moves.push(priority_moves.first)
    end
    
    # 4. Add STAB moves
    stab_to_add = [stab_attacks.first].compact
    if stab_attacks.length > 1 && selected_moves.length < 3
      stab_to_add.push(stab_attacks[1])
    end
    
    stab_to_add.each do |move|
      if selected_moves.length < 4 && move
        selected_moves.push(move)
      end
    end
    
    # 5. Add coverage moves
    if !coverage_attacks.empty?
      # Get top coverage moves, prioritizing different types
      coverage_by_type = {}
      coverage_attacks.each do |move_id|
        move_type = GameData::Move.get(move_id).type
        if !coverage_by_type[move_type] || 
           GameData::Move.get(coverage_by_type[move_type]).power < GameData::Move.get(move_id).power
          coverage_by_type[move_type] = move_id
        end
      end
      
      # Get best coverage moves by type
      best_coverage = coverage_by_type.values.sort_by { |move_id| -GameData::Move.get(move_id).power }
      
      # Add up to 2 coverage moves
      best_coverage[0..1].each do |move|
        if selected_moves.length < 4 && move
          selected_moves.push(move)
        end
      end
    end
    
    # 6. Add status move if we still have room
    if selected_moves.length < 4 && !status_moves.empty?
      # Prioritize useful status moves
      priority_status = [:WILLOWISP, :THUNDERWAVE, :TOXIC, :LEECHSEED, :STEALTHROCK, 
                         :SPIKES, :SUBSTITUTE, :PROTECT]
      
      best_status = status_moves.find { |move_id| priority_status.include?(move_id) }
      selected_moves.push(best_status || status_moves.sample) if best_status || !status_moves.empty?
    end
    
    # 7. If we still don't have 4 moves, add more from the available pool
    remaining_slots = 4 - selected_moves.length
    if remaining_slots > 0
      # Create a pool of all moves, excluding ones already selected
      all_moves = (stab_attacks + coverage_attacks + status_moves + setup_moves + recovery_moves + priority_moves).uniq
      all_moves -= selected_moves
      
      # Add random moves from the pool
      additional_moves = all_moves.sample(remaining_slots)
      selected_moves.concat(additional_moves) if additional_moves
    end
    
    # Teach the selected moves to the Pokémon
    selected_moves.compact.uniq[0..3].each do |move_id|
      if GameData::Move.exists?(move_id)
        pkmn.learn_move(move_id)
      end
    end
    
    # If somehow we still don't have 4 moves, fill with random compatible moves
    if pkmn.moves.length < 4
      remaining = 4 - pkmn.moves.length
      available_moves.shuffle[0...remaining].each do |move_id|
        if GameData::Move.exists?(move_id) && !pkmn.moves.any? { |m| m.id == move_id }
          pkmn.learn_move(move_id)
        end
      end
    end
  end
  
  # Apply competitive EVs based on the Pokémon's stats
  def self.apply_competitive_evs(pkmn)
    # Reset EVs
    GameData::Stat.each_main { |s| pkmn.ev[s.id] = 0 }
    
    # Determine the Pokémon's role based on base stats
    physical_attack = pkmn.baseStats[:ATTACK]
    special_attack = pkmn.baseStats[:SPECIAL_ATTACK]
    defense = pkmn.baseStats[:DEFENSE]
    special_defense = pkmn.baseStats[:SPECIAL_DEFENSE]
    speed = pkmn.baseStats[:SPEED]
    hp = pkmn.baseStats[:HP]
    
    # Simple role determination
    is_physical_attacker = physical_attack > special_attack
    is_fast = speed > 80
    is_bulky = (defense + special_defense) > 150
    
    # Choose an appropriate EV distribution
    ev_spread = nil
    
    if is_physical_attacker
      if is_fast
        ev_spread = CHAMPIONS2D::EV_DISTRIBUTIONS[5] # Fast Physical Attacker
      elsif is_bulky
        ev_spread = CHAMPIONS2D::EV_DISTRIBUTIONS[7] # Bulky Attacker
      else
        ev_spread = CHAMPIONS2D::EV_DISTRIBUTIONS[0] # Physical Sweeper
      end
    else
      if is_fast
        ev_spread = CHAMPIONS2D::EV_DISTRIBUTIONS[6] # Fast Special Attacker
      elsif is_bulky
        ev_spread = CHAMPIONS2D::EV_DISTRIBUTIONS[8] # Bulky Special Attacker
      else
        ev_spread = CHAMPIONS2D::EV_DISTRIBUTIONS[1] # Special Sweeper
      end
    end
    
    # For exceptionally defensive Pokémon
    if physical_attack < 60 && special_attack < 60
      if defense > special_defense
        ev_spread = CHAMPIONS2D::EV_DISTRIBUTIONS[2] # Physical Wall
      else
        ev_spread = CHAMPIONS2D::EV_DISTRIBUTIONS[3] # Special Wall
      end
    end
    
    # Apply the chosen EV spread
    ev_spread.each do |stat, value|
      pkmn.ev[stat] = value if pkmn.ev.has_key?(stat)
    end
    
    # Recalculate stats with new EVs
    pkmn.calc_stats
  end
  
  # Assign a competitive nature based on the Pokémon's role
  def self.assign_competitive_nature(pkmn)
    # Determine the Pokémon's role based on base stats
    physical_attack = pkmn.baseStats[:ATTACK]
    special_attack = pkmn.baseStats[:SPECIAL_ATTACK]
    defense = pkmn.baseStats[:DEFENSE]
    special_defense = pkmn.baseStats[:SPECIAL_DEFENSE]
    speed = pkmn.baseStats[:SPEED]
    
    # Identify which attacking stat is better
    is_physical_attacker = physical_attack > special_attack
    
    # Define nature options based on role
    natures = []
    
    if is_physical_attacker
      if speed >= 80
        natures = [:JOLLY, :ADAMANT] # +Speed or +Attack, -Sp.Atk
      elsif defense < special_defense
        natures = [:ADAMANT, :IMPISH] # +Attack or +Defense, -Sp.Atk or -Speed
      else
        natures = [:ADAMANT, :BRAVE] # +Attack, -Sp.Atk or -Speed
      end
    else
      if speed >= 80
        natures = [:TIMID, :MODEST] # +Speed or +Sp.Atk, -Attack
      elsif defense < special_defense
        natures = [:MODEST, :CALM] # +Sp.Atk or +Sp.Def, -Attack
      else
        natures = [:MODEST, :QUIET] # +Sp.Atk, -Attack or -Speed
      end
    end
    
    # For purely defensive Pokémon
    if physical_attack < 60 && special_attack < 60
      if defense > special_defense
        natures = [:IMPISH, :RELAXED] # +Defense, -Sp.Atk or -Speed
      else
        natures = [:CALM, :SASSY] # +Sp.Def, -Attack or -Speed
      end
    end
    
    # Apply a nature from the selected options
    pkmn.nature = natures.sample
  end
  
  # Generate a single rental Pokemon with random attributes
  def self.generate_rental_pokemon
    # Get a list of all species, excluding special forms
    valid_species = []
    strong_species = []
    legendary_species = []
    
    GameData::Species.each do |species_data|
      # Skip special forms - only use form 0 (normal form)
      next if species_data.form != 0
      
      # Skip species that are megas, primals, or other special forms
      next if species_data.id.to_s.include?("_MEGA") || 
              species_data.id.to_s.include?("_PRIMAL") ||
              species_data.id.to_s.include?("_GMAX") ||
              species_data.id.to_s.include?("_ALOLAN") ||
              species_data.id.to_s.include?("_GALARIAN") ||
              species_data.id.to_s.include?("_ORIGIN") ||
              species_data.id.to_s.include?("_ETERNAMAX") ||
              species_data.id.to_s.include?("_SHADOW")
      
      # Calculate base stat total
      bst = 0
      bst += species_data.base_stats[:HP] if species_data.base_stats[:HP]
      bst += species_data.base_stats[:ATTACK] if species_data.base_stats[:ATTACK]
      bst += species_data.base_stats[:DEFENSE] if species_data.base_stats[:DEFENSE]
      bst += species_data.base_stats[:SPECIAL_ATTACK] if species_data.base_stats[:SPECIAL_ATTACK]
      bst += species_data.base_stats[:SPECIAL_DEFENSE] if species_data.base_stats[:SPECIAL_DEFENSE]
      bst += species_data.base_stats[:SPEED] if species_data.base_stats[:SPEED]
      
      # Check if this is a strong Pokémon (high stats)
      is_strong = false
      if bst >= CHAMPIONS2D::MIN_BST
        # Has high BST, now check offensive stats
        attack = species_data.base_stats[:ATTACK] || 0
        sp_attack = species_data.base_stats[:SPECIAL_ATTACK] || 0
        speed = species_data.base_stats[:SPEED] || 0
        
        if (attack >= CHAMPIONS2D::MIN_OFFENSIVE || sp_attack >= CHAMPIONS2D::MIN_OFFENSIVE) && 
           speed >= CHAMPIONS2D::MIN_SPEED
          is_strong = true
        end
      end
      
      # Check if it's a legendary
      is_legendary = species_data.respond_to?(:legendary?) ? species_data.legendary? : false
      
      # Alternative check for legendary status if the method doesn't exist
      if !species_data.respond_to?(:legendary?)
        legendary_ids = [
          :ARTICUNO, :ZAPDOS, :MOLTRES, :MEWTWO, :MEW, 
          :RAIKOU, :ENTEI, :SUICUNE, :LUGIA, :HOOH, :CELEBI,
          :REGIROCK, :REGICE, :REGISTEEL, :LATIAS, :LATIOS, :KYOGRE, :GROUDON, :RAYQUAZA, :JIRACHI, :DEOXYS,
          :UXIE, :MESPRIT, :AZELF, :DIALGA, :PALKIA, :HEATRAN, :REGIGIGAS, :GIRATINA, :CRESSELIA, :PHIONE, :MANAPHY, :DARKRAI, :SHAYMIN, :ARCEUS,
          :VICTINI, :COBALION, :TERRAKION, :VIRIZION, :TORNADUS, :THUNDURUS, :RESHIRAM, :ZEKROM, :LANDORUS, :KYUREM, :KELDEO, :MELOETTA, :GENESECT,
          :XERNEAS, :YVELTAL, :ZYGARDE, :DIANCIE, :HOOPA, :VOLCANION,
          :TAPUKOKO, :TAPULELE, :TAPUBULU, :TAPUFINI, :COSMOG, :COSMOEM, :SOLGALEO, :LUNALA, :NIHILEGO, :BUZZWOLE, :PHEROMOSA, :XURKITREE, :CELESTEELA, :KARTANA, :GUZZLORD, :NECROZMA, :MAGEARNA, :MARSHADOW, :POIPOLE, :NAGANADEL, :STAKATAKA, :BLACEPHALON, :ZERAORA,
          :MELTAN, :MELMETAL
        ]
        is_legendary = legendary_ids.include?(species_data.id)
      end
      
      # Categorize the species
      if is_legendary
        legendary_species.push(species_data.id)
      elsif is_strong
        strong_species.push(species_data.id)
      else
        valid_species.push(species_data.id)
      end
    end
    
    # Select a species based on our categories
    species = nil
    
    # Determine if we should include a legendary (based on chance)
    if !legendary_species.empty? && rand(100) < CHAMPIONS2D::LEGENDARY_CHANCE
      species = legendary_species.sample
    elsif !strong_species.empty?
      # 80% chance to pick from strong species if available
      if rand(100) < 80
        species = strong_species.sample
      else
        species = valid_species.sample
      end
    else
      species = valid_species.sample
    end
    
    # Create the Pokémon
    pkmn = Pokemon.new(species, CHAMPIONS2D::RENTAL_LEVEL)
    pkmn.form = 0  # Ensure normal form
    
    # Set the OT to CHAMPIONS2D
    pkmn.owner.name = CHAMPIONS2D::OT_NAME
    pkmn.owner.id = $player ? $player.make_foreign_ID : rand(2**16) | rand(2**16) << 16
    
    # Give random ability
    # Fixed: Use ability number and species abilities instead of compatibility check
    if pkmn.species_data.abilities
      ability_ids = pkmn.species_data.abilities.compact
      if ability_ids.length > 0
        pkmn.ability = ability_ids.sample
      end
    end
    
    # Set perfect IVs
    GameData::Stat.each_main do |s|
      pkmn.iv[s.id] = CHAMPIONS2D::GUARANTEED_IVS
    end
    
    # Apply a competitive EV spread based on the Pokémon's stats
    apply_competitive_evs(pkmn)
    
    # Set a beneficial nature for the Pokémon's best stats
    assign_competitive_nature(pkmn)
    
    # Give competitive movesets instead of random ones
    setup_competitive_moveset(pkmn)
    
    # Always use Premier Ball
    pkmn.poke_ball = :PREMIERBALL
    
    # Set met data
    pkmn.obtain_method = 0  # Met
    pkmn.obtain_level = CHAMPIONS2D::RENTAL_LEVEL
    pkmn.obtain_text = _INTL("from a rental service")
    pkmn.timeReceived = Time.now
    
    # Recalculate stats
    pkmn.calc_stats
    
    # Return the created Pokemon
    return pkmn
  end
  
  # Replace party with rental team
  def self.replace_rental_team
    # Count how many rental Pokemon are currently in the party
    rental_count = 0
    $player.party.each do |pkmn|
      rental_count += 1 if pkmn.owner.name == CHAMPIONS2D::OT_NAME
    end
    
    # Transfer any non-CHAMPIONS2D Pokemon to PC boxes
    non_rental_sent = 0
    non_rental_pokemon = []
    
    # Collect non-rental Pokémon first
    $player.party.each do |pkmn|
      next if pkmn.owner.name == CHAMPIONS2D::OT_NAME
      non_rental_pokemon.push(pkmn)
    end
    
    # Store them in PC
    non_rental_pokemon.each do |pkmn|
      if $PokemonStorage.pbStoreCaught(pkmn)
        non_rental_sent += 1
      end
    end
    
    # Now update party to remove all stored Pokémon
    $player.party.delete_if { |pkmn| pkmn.owner.name != CHAMPIONS2D::OT_NAME }
    
    # Remove any remaining CHAMPIONS2D Pokemon
    $player.party.delete_if { |pkmn| pkmn.owner.name == CHAMPIONS2D::OT_NAME }
    
    # Add 6 new rental Pokemon
    6.times do
      # Only add if party isn't full
      break if $player.party.length >= 6
      $player.party.push(generate_rental_pokemon)
    end
    
    # Return the counts of replaced Pokemon and sent to boxes
    return [rental_count, non_rental_sent]
  end
end

#===============================================================================
# Script command for calling the rental team function
#===============================================================================

def pbRentChampions2DTeam
  replaced, sent_to_box = Champions2DRentalTeam.replace_rental_team
  
  if replaced > 0
    pbMessage(_INTL("Your previous CHAMPIONS2D rental Pokémon have been returned."))
  end
  
  # Show message if any Pokemon were sent to boxes
  if sent_to_box > 0
    pbMessage(_INTL("{1} of your Pokémon have been sent to the PC storage system.", sent_to_box))
  end
  
  pbMessage(_INTL("Here's your new rental team!"))
  pbMessage(_INTL("6 CHAMPIONS2D rental Pokémon have been added to your party."))
  
  # Play a sound effect
  pbSEPlay("Pkmn move learnt")
end

#===============================================================================
# Debug menu integration
#===============================================================================

# Command for debug menu
MenuHandlers.add(:debug_menu, :champions2d_rental_team, {
  "name"        => _INTL("Get CHAMPIONS2D Rental Team"),
  "parent"      => :pokemon_menu,
  "description" => _INTL("Replace your party with six rental Pokémon."),
  "effect"      => proc {
    pbRentChampions2DTeam
    next false
  }
})

# Add to pause menu
MenuHandlers.add(:pause_menu, :champions2d_rental_team, {
  "name"      => _INTL("Rental Team"),
  "order"     => 66,
  "condition" => proc { next $player && $PokemonStorage },
  "effect"    => proc { |menu|
    pbMessage(_INTL("Would you like to rent a team of Pokémon?"))
    if pbConfirmMessage(_INTL("This will replace your current team with rental Pokémon."))
      pbRentChampions2DTeam
    end
    next false
  }
})