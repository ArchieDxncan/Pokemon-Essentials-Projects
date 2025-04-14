#===============================================================================
# Storage Import Plugin for Pokemon Essentials v21.1
#===============================================================================

# Storage directory
STORAGE_DIR = "STORAGE"

#===============================================================================
# Helper functions for JSON handling since Essentials might not have json library
#===============================================================================

module StorageHelper
  # Convert a complex object to a string (basic JSON-like format)
  def self.object_to_string(obj)
    case obj
    when Hash
      "{" + obj.map { |k, v| "\"#{k}\":#{object_to_string(v)}" }.join(",") + "}"
    when Array
      "[" + obj.map { |v| object_to_string(v) }.join(",") + "]"
    when String
      "\"#{obj.gsub('"', '\\"')}\""
    when Numeric, true, false, nil
      obj.to_s
    else
      "\"#{obj.to_s}\""
    end
  end
  
  # Parse a simple object from string (very basic support)
  def self.string_to_object(str)
    result = {}
    # Modified to handle null values in JSON
    # Replace JSON null with Ruby nil
    str = str.gsub(/:\s*null\b/, ': nil')
    # Replace numerical boolean values (0/1) with true/false
    str = str.gsub(/:\s*0\b(?!\.)/, ': false')
    str = str.gsub(/:\s*1\b(?!\.)/, ': true')
    
    # Just using eval for simplicity - in production would need proper parser
    begin
      result = eval(str)
    rescue => e
      puts "Failed to parse: #{str[0..100]}... Error: #{e.message}"
    end
    return result
  end
  
  # Load object from a file
  def self.load_object(filename)
    if File.exist?(filename)
      data = File.read(filename)
      if defined?(pbLoadJSON)
        return pbLoadJSON(data)
      else
        return string_to_object(data)
      end
    end
    return nil
  end
  
  # Convert move name from hyphenated format to upper case without symbols
  def self.normalize_move_name(move_name)
    return nil if !move_name
    return move_name.to_s.upcase.gsub(/[^A-Z0-9]/, '')
  end
  
  # Convert stat names from JSON format to Ruby expected format
  def self.normalize_stat_name(stat_name)
    return nil if !stat_name
    case stat_name.to_s.downcase
    when "hp" then return :HP
    when "attack" then return :ATTACK
    when "defence", "defense" then return :DEFENSE
    when "special_attack", "spatk" then return :SPECIAL_ATTACK
    when "special_defence", "special_defense", "spdef" then return :SPECIAL_DEFENSE
    when "speed" then return :SPEED
    else return stat_name.to_s.upcase.to_sym
    end
  end
  
  # Safely convert to integer, handling different types
  def self.safe_to_i(value)
    case value
    when Integer
      return value
    when String
      return value.to_i
    when TrueClass
      return 1
    when FalseClass
      return 0
    when NilClass
      return 0
    else
      return value.to_i rescue 0
    end
  end
end

#===============================================================================
# Clear all Pokemon from storage and party - SINGLE DEFINITION
#===============================================================================

# Clear all Pokemon from storage and party
def clear_all_pokemon
  # Clear party Pokemon
  while $player && $player.party && !$player.party.empty?
    $player.party.delete_at(0)
  end
  
  # Clear storage Pokemon
  if $PokemonStorage
    for box in 0...$PokemonStorage.maxBoxes
      for slot in 0...$PokemonStorage.maxPokemon(box)
        $PokemonStorage[box, slot] = nil
      end
    end
  end
  
  puts "Cleared all Pokemon from party and storage."
  return true
end

#===============================================================================
# Global methods for event compatibility - MUST be defined at module level
#===============================================================================

# Function to be called from events - ALWAYS clears first
def pbImportPokemonFromStorage(clear_first = true)
  # Always clear first - removed the condition check
  #pbMessage(_INTL("Clearing all Pokémon..."))
  result = clear_all_pokemon
  #if !result
  #  pbMessage(_INTL("Error: Could not clear Pokémon."))
  #  return false
  #end
  #pbMessage(_INTL("All Pokémon have been cleared."))
  
  pbMessage(_INTL("Importing from STORAGE folder..."))
  count = import_all_pokemon
  pbMessage(_INTL("Import complete! {1} Pokémon imported.", count))
  
  return true
end

#===============================================================================
# Pokemon storage functions
#===============================================================================

# Import a Pokemon from storage
def import_pokemon_from_storage(filename)
  full_path = File.join(STORAGE_DIR, filename)
  return nil if !File.exist?(full_path)
  
  # Load data
  data = StorageHelper.load_object(full_path)
  return nil if !data
  
  begin
    # Get species - required field
    species_name = data[:species] || data["species"]
    if !species_name
      puts "Error: No species found in #{filename}"
      return nil
    end
    
    # Create Pokemon
    species_sym = GameData::Species.get(species_name.to_s.upcase.gsub(/\W/, '')).id
    level = StorageHelper.safe_to_i(data[:level] || data["level"] || 50)
    
    pkmn = Pokemon.new(species_sym, level)
    
    # Set nickname
    if data[:nickname] || data["nickname"]
      pkmn.name = data[:nickname] || data["nickname"]
    end
    
    # Set ability (by name)
    ability_name = data[:ability] || data["ability"]
    if ability_name
      ability_sym = ability_name.to_s.upcase.gsub(/\W/, '').to_sym
      if GameData::Ability.exists?(ability_sym)
        pkmn.ability = ability_sym
      else
        # Try to find the ability by index based on species abilities
        if ability_name.to_s.downcase == "hidden"
          pkmn.ability_index = 2  # Hidden ability
        elsif pkmn.species_data.abilities.include?(ability_sym)
          if pkmn.species_data.abilities[0] == ability_sym
            pkmn.ability_index = 0  # First ability
          elsif pkmn.species_data.abilities[1] == ability_sym
            pkmn.ability_index = 1  # Second ability
          end
        end
      end
    end
    
    # Set moves
    moves_data = data[:moves] || data["moves"]
    if moves_data && moves_data.is_a?(Array) && moves_data.length > 0
      pkmn.moves.clear
      moves_data.each do |move_name|
        next unless move_name # Skip nil moves
        normalized_move = StorageHelper.normalize_move_name(move_name)
        move_sym = normalized_move.to_sym
        if GameData::Move.exists?(move_sym)
          pkmn.learn_move(move_sym)
        else
          puts "Warning: Move not found: #{move_name}"
        end
      end
    end
    
    # Set IVs
    ivs_data = data[:ivs] || data["ivs"]
    if ivs_data && ivs_data.is_a?(Hash)
      ivs_data.each do |stat, value|
        next unless stat && value
        stat_sym = StorageHelper.normalize_stat_name(stat)
        pkmn.iv[stat_sym] = StorageHelper.safe_to_i(value) if pkmn.iv.has_key?(stat_sym)
      end
    end
    
    # Set EVs
    evs_data = data[:evs] || data["evs"]
    if evs_data && evs_data.is_a?(Hash)
      evs_data.each do |stat, value|
        next unless stat && value
        stat_sym = StorageHelper.normalize_stat_name(stat)
        pkmn.ev[stat_sym] = StorageHelper.safe_to_i(value) if pkmn.ev.has_key?(stat_sym)
      end
    end
    
    # Set nature
    nature_name = data[:nature] || data["nature"]
    if nature_name
      nature_sym = nature_name.to_s.upcase.gsub(/\W/, '').to_sym
      if GameData::Nature.exists?(nature_sym)
        pkmn.nature = nature_sym
      end
    end
    
    # Set gender
    gender_str = data[:gender] || data["gender"]
    if gender_str
      case gender_str.to_s.upcase
      when "MALE" then pkmn.gender = 0
      when "FEMALE" then pkmn.gender = 1
      else pkmn.gender = 2
      end
    end
    
    # Set form
    form_data = data[:form_id] || data["form_id"] || data[:form] || data["form"]
    if form_data
      if form_data.is_a?(Numeric)
        pkmn.form = form_data
      elsif form_data.is_a?(String) && form_data.downcase == "normal"
        pkmn.form = 0
      else
        # Try to map form name to number - depends on species implementation
        pkmn.form = 0  # Default to normal form
      end
    end
    
    # Set shiny status
    shiny_val = data[:shiny] || data["shiny"]
    if shiny_val.is_a?(Integer)
      pkmn.shiny = (shiny_val != 0)
    elsif shiny_val.is_a?(TrueClass) || shiny_val.is_a?(FalseClass)
      pkmn.shiny = shiny_val
    end
    
    # Set happiness/friendship
    friendship_val = data[:friendship] || data["friendship"]
    pkmn.happiness = StorageHelper.safe_to_i(friendship_val) if friendship_val
    
    # Set experience
    exp_val = data[:experience] || data["experience"]
    pkmn.exp = StorageHelper.safe_to_i(exp_val) if exp_val
    
    # Set Poké Ball
    ball_str = data[:caught_ball] || data["caught_ball"]
    if ball_str
      ball_name = ball_str.to_s.gsub(/cobblemon:/, '')
      ball_sym = ball_name.gsub(/[^a-zA-Z0-9_]/, '_').to_sym
      if GameData::Item.exists?(ball_sym)
        pkmn.poke_ball = ball_sym 
      else
        # Try to find a matching ball item
        cleaned_name = ball_name.gsub(/[^a-zA-Z0-9]/, '')
        possible_balls = [:POKEBALL, :GREATBALL, :ULTRABALL, :MASTERBALL, 
                          :SAFARIBALL, :NETBALL, :DIVEBALL, :NESTBALL, :REPEATBALL, 
                          :TIMERBALL, :LUXURYBALL, :PREMIERBALL, :DUSKBALL, 
                          :HEALBALL, :QUICKBALL, :CHERISHBALL, :FASTBALL, 
                          :LEVELBALL, :LUREBALL, :HEAVYBALL, :LOVEBALL, 
                          :FRIENDBALL, :MOONBALL, :SPORTBALL, :DREAMBALL]
        possible_balls.each do |ball|
          if ball.to_s.upcase.include?(cleaned_name.upcase)
            pkmn.poke_ball = ball
            break
          end
        end
        # Default to regular Poké Ball if no match found
        pkmn.poke_ball = :POKEBALL if !pkmn.poke_ball
      end
    end
    
    # Set met info
    met_level = data[:met_level] || data["met_level"]
    pkmn.obtain_level = StorageHelper.safe_to_i(met_level) if met_level
    
    met_location = data[:met_location] || data["met_location"]
    pkmn.obtain_text = met_location.to_s if met_location
    
    # Set original trainer info
    original_trainer = data[:original_trainer] || data["original_trainer"]
    if original_trainer
      pkmn.owner.name = original_trainer.to_s
    end
    
    # Set trainer ID from the JSON, or generate a random one if not available
    tid = data[:tid] || data["tid"]
    if tid && tid != "null"
      pkmn.owner.id = StorageHelper.safe_to_i(tid)
    else
      # Set to foreign ID to indicate not the current player
      pkmn.owner.id = $player ? $player.make_foreign_ID : rand(2**16) | rand(2**16) << 16
    end
    
    # Set language
    language = data[:language] || data["language"]
    pkmn.owner.language = StorageHelper.safe_to_i(language) if language
    
    # Set Time received
    met_date = data[:met_date] || data["met_date"]
    if met_date
      begin
        if met_date =~ /(\d{4})-(\d{1,2})-(\d{1,2})/
          year, month, day = $1.to_i, $2.to_i, $3.to_i
          pkmn.timeReceived = Time.new(year, month, day)
        end
      rescue
        pkmn.timeReceived = Time.now
      end
    else
      pkmn.timeReceived = Time.now
    end
    
    # Recalculate stats
    pkmn.calc_stats
    
    return pkmn
  rescue => e
    puts "Error importing Pokemon: #{e.message}"
    puts e.backtrace.join("\n")
    return nil
  end
end

# Import all Pokemon from storage
def import_all_pokemon
  return 0 if !Dir.exist?(STORAGE_DIR)
  
  files = Dir.glob(File.join(STORAGE_DIR, "*.json"))
  count = 0
  
  files.each do |file|
    puts "Importing: #{file}"
    filename = File.basename(file)
    pkmn = import_pokemon_from_storage(filename)
    
    if pkmn
      if $PokemonStorage && $PokemonStorage.pbStoreCaught(pkmn)
        count += 1
        puts "Successfully imported: #{pkmn.name} (#{pkmn.speciesName})"
      else
        puts "Failed to store in Pokemon Storage: #{filename}"
      end
    else
      puts "Failed to import: #{filename}"
    end
  end
  
  puts "Imported #{count} Pokemon out of #{files.length} files"
  return count
end

#===============================================================================
# Menu handlers for the plugin
#===============================================================================

# Add menu handlers if debug mode is enabled
if $DEBUG
  MenuHandlers.add(:debug_menu, :storage_import, {
    "name"        => _INTL("Import from STORAGE"),
    "parent"      => :pokemon_menu,
    "description" => _INTL("Import all Pokémon from the STORAGE folder."),
    "effect"      => proc { |sprites, viewport|
      # Always clear first
      pbMessage(_INTL("Clearing all Pokémon..."))
      clear_all_pokemon
      pbMessage(_INTL("All Pokémon have been cleared."))
      
      pbMessage(_INTL("Importing from STORAGE folder..."))
      count = import_all_pokemon
      pbMessage(_INTL("{1} Pokémon imported from STORAGE folder.", count))
      next false
    }
  })
  
  # Remove redundant menu handler that does the same thing
  # The above handler now always clears first
end

# Add Storage Import to Pause Menu
MenuHandlers.add(:pause_menu, :storage_import, {
  "name"      => _INTL("Storage Import"),
  "order"     => 65,
  "condition" => proc { next $Trainer && $PokemonStorage },
  "effect"    => proc { |menu|
    # Modified to always clear before importing
    pbMessage(_INTL("NOTICE: This will clear ALL Pokémon and import new ones."))
    
    # Always clear first before importing
    pbMessage(_INTL("Clearing all Pokémon..."))
    if clear_all_pokemon
      pbMessage(_INTL("All Pokémon have been cleared."))
      
      pbMessage(_INTL("Importing from STORAGE folder..."))
      import_count = import_all_pokemon
      pbMessage(_INTL("Import complete! {1} Pokémon imported.", import_count))
    else
      pbMessage(_INTL("Error: Could not clear Pokémon storage."))
    end
    
    next false
  }
})

#===============================================================================
# Event command for calling the importer
#===============================================================================

# Import all Pokemon with option to clear first (now always clears)
def import_all_pokemon_with_clear(clear_first = true)
  # Always clear all Pokemon regardless of parameter
  clear_all_pokemon
  
  # Then import all Pokemon
  return import_all_pokemon
end

# Initialize - Create storage directory if it doesn't exist
Dir.mkdir(STORAGE_DIR) if !Dir.exist?(STORAGE_DIR)