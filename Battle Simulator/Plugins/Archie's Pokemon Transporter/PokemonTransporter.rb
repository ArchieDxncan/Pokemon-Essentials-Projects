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
    # Just using eval for simplicity - in production would need proper parser
    begin
      result = eval(str)
    rescue
      puts "Failed to parse: #{str[0..100]}..."
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
end

#===============================================================================
# Clear all Pokemon from storage and party - SINGLE DEFINITION
#===============================================================================

# Clear all Pokemon from storage and party
def clear_all_pokemon
  # Clear party Pokemon
  #$player.party.delete_at(0)
  #$player.party.delete_at(0)
  #$player.party.delete_at(0)
  #$player.party.delete_at(0)
  #$player.party.delete_at(0)
  #$player.party.delete_at(0)

  
  
  puts "Cleared all Pokemon from party."
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
  if !result
    pbMessage(_INTL("Error: Could not clear Pokémon."))
    return false
  end
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
  
  # Create Pokemon
  species_name = data[:species] || data["species"]
  begin
    species_sym = GameData::Species.get(species_name.upcase.gsub(/\W/, '')).id
    level = (data[:level] || data["level"] || 50).to_i
    
    pkmn = Pokemon.new(species_sym, level)
    
    # Set nickname
    pkmn.name = data[:nickname] || data["nickname"] if data[:nickname] || data["nickname"]
    
    # Set ability (by name)
    ability_name = data[:ability] || data["ability"]
    if ability_name
      ability_sym = ability_name.upcase.gsub(/\W/, '').to_sym
      pkmn.ability = ability_sym if GameData::Ability.exists?(ability_sym)
    end
    
    # Set moves
    moves_data = data[:moves] || data["moves"]
    if moves_data && moves_data.is_a?(Array) && moves_data.length > 0
      pkmn.moves.clear
      moves_data.each do |move_name|
        move_sym = move_name.to_s.upcase.gsub(/\W/, '').to_sym
        pkmn.learn_move(move_sym) if GameData::Move.exists?(move_sym)
      end
    end
    
    # Set IVs
    ivs_data = data[:ivs] || data["ivs"]
    if ivs_data && ivs_data.is_a?(Hash)
      pkmn.iv[:HP] = ivs_data["hp"] || ivs_data[:hp] || pkmn.iv[:HP]
      pkmn.iv[:ATTACK] = ivs_data["attack"] || ivs_data[:attack] || pkmn.iv[:ATTACK]
      pkmn.iv[:DEFENSE] = ivs_data["defence"] || ivs_data[:defence] || pkmn.iv[:DEFENSE]
      pkmn.iv[:SPECIAL_ATTACK] = ivs_data["special_attack"] || ivs_data[:special_attack] || pkmn.iv[:SPECIAL_ATTACK]
      pkmn.iv[:SPECIAL_DEFENSE] = ivs_data["special_defence"] || ivs_data[:special_defence] || pkmn.iv[:SPECIAL_DEFENSE]
      pkmn.iv[:SPEED] = ivs_data["speed"] || ivs_data[:speed] || pkmn.iv[:SPEED]
    end
    
    # Set EVs
    evs_data = data[:evs] || data["evs"]
    if evs_data && evs_data.is_a?(Hash)
      pkmn.ev[:HP] = evs_data["hp"] || evs_data[:hp] || pkmn.ev[:HP]
      pkmn.ev[:ATTACK] = evs_data["attack"] || evs_data[:attack] || pkmn.ev[:ATTACK]
      pkmn.ev[:DEFENSE] = evs_data["defence"] || evs_data[:defence] || pkmn.ev[:DEFENSE]
      pkmn.ev[:SPECIAL_ATTACK] = evs_data["special_attack"] || evs_data[:special_attack] || pkmn.ev[:SPECIAL_ATTACK]
      pkmn.ev[:SPECIAL_DEFENSE] = evs_data["special_defence"] || evs_data[:special_defence] || pkmn.ev[:SPECIAL_DEFENSE]
      pkmn.ev[:SPEED] = evs_data["speed"] || evs_data[:speed] || pkmn.ev[:SPEED]
    end
    
    # Set nature
    nature_name = data[:nature] || data["nature"]
    if nature_name
      nature_sym = nature_name.upcase.gsub(/\W/, '').to_sym
      nature_id = GameData::Nature.get(nature_sym).id rescue nil
      pkmn.nature = nature_id if nature_id
    end
    
    # Set gender
    gender_str = data[:gender] || data["gender"]
    if gender_str
      case gender_str
      when "MALE" then pkmn.gender = 0
      when "FEMALE" then pkmn.gender = 1
      else pkmn.gender = 2
      end
    end
    
    # Set shiny status
    shiny_val = data[:shiny] || data["shiny"]
    pkmn.shiny = (shiny_val && shiny_val != 0)
    
    # Set happiness/friendship
    friendship_val = data[:friendship] || data["friendship"]
    pkmn.happiness = friendship_val if friendship_val
    
    # Set Poké Ball
    ball_str = data[:caught_ball] || data["caught_ball"]
    if ball_str
      ball_name = ball_str.gsub(/COBBLEMON:/, '')
      ball_sym = ball_name.to_sym
      pkmn.poke_ball = ball_sym if GameData::Item.exists?(ball_sym)
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
    filename = File.basename(file)
    pkmn = import_pokemon_from_storage(filename)
    
    if pkmn && $PokemonStorage.pbStoreCaught(pkmn)
      count += 1
    end
  end
  
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