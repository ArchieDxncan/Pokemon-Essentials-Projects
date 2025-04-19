# ===============================================================================
# Cable Club Connection Methods Update
# ===============================================================================
# This file contains the modifications needed to support both direct link code
# connections and random matchmaking in the Cable Club.
# 
# To implement this, place this code in your Cable Club plugin folder and make sure
# it loads after the main Cable Club files but before any other Cable Club scripts.

class CableClubScreen
  alias :original_pbAttemptConnection :pbAttemptConnection
  
  # Replace the connection method with our new selection system
  def pbAttemptConnection
    if $player.party_count == 0
      pbDisplay(_INTL("I'm sorry, you must have a Pokémon to enter the Cable Club."))
      return false
    end
    
    # Ask the player how they want to connect
    commands = [_INTL("Start Searching"), _INTL("Set Link Code"), _INTL("Cancel")]
    cmd = pbShowCommands(_INTL("How would you like to connect?"), commands, 3)
    
    case cmd
    when 0  # Start Searching (Random Matchmaking)
      begin
        # Use special code "00000" to indicate random matchmaking to the server
        # The server will identify this and place the player in a random matchmaking queue
        pbConnectServer("00000")
        raise Connection::Disconnected.new("disconnected")
      rescue Connection::Disconnected => e
        return handle_connection_error(e)
      rescue Errno::ECONNABORTED, Errno::ECONNREFUSED => e
        return handle_network_error(e)
      rescue => e
        pbPrintException(e)
        pbDisplay(_INTL("I'm sorry, the Cable Club has malfunctioned!"))
        return false
      ensure
        pbHideMessageBox
      end
      
    when 1  # Set Link Code (Direct Connection)
      begin
        msg = _ISPRINTF("What's the ID of the trainer you're searching for? (Your ID: {1:05d})",$player.public_ID($player.id))
        partner_id = ""
        loop do
          partner_id = pbEnterText(msg, partner_id, false, 5)
          return false if partner_id.empty?
          break if partner_id =~ /^[0-9]{5}$/
          
          # Don't allow using the special random matchmaking code
          if partner_id == "00000"
            pbDisplay(_INTL("That ID is reserved for random matchmaking."))
          end
        end
        
        pbConnectServer(partner_id)
        raise Connection::Disconnected.new("disconnected")
      rescue Connection::Disconnected => e
        return handle_connection_error(e)
      rescue Errno::ECONNABORTED, Errno::ECONNREFUSED => e
        return handle_network_error(e)
      rescue => e
        pbPrintException(e)
        pbDisplay(_INTL("I'm sorry, the Cable Club has malfunctioned!"))
        return false
      ensure
        pbHideMessageBox
      end
      
    else  # Cancel
      return false
    end
  end
  
  # Helper method to handle connection errors
  def handle_connection_error(e)
    case e.message
    when "disconnected"
      pbDisplay(_INTL("Thank you for using the Cable Club. We hope to see you again soon."))
      return true
    when "invalid party"
      pbDisplay(_INTL("I'm sorry, your party contains Pokémon not allowed in the Cable Club."))
      return false
    when "peer disconnected"
      pbDisplay(_INTL("I'm sorry, the other trainer has disconnected."))
      return true
    when "invalid version"
      pbDisplay(_INTL("I'm sorry, your game version is out of date compared to the Cable Club."))
      return false
    else
      pbDisplay(_INTL("I'm sorry, the Cable Club server has malfunctioned!"))
      return false
    end
  end
  
  # Helper method to handle network errors
  def handle_network_error(e)
    if e.is_a?(Errno::ECONNABORTED)
      pbDisplay(_INTL("I'm sorry, the other trainer has disconnected."))
      return true
    elsif e.is_a?(Errno::ECONNREFUSED)
      pbDisplay(_INTL("I'm sorry, the Cable Club server is down at the moment."))
      return false
    end
  end
  
  # Override await_server method with updated messages
  def await_server(connection, partner_id)
    change_state(:await_server) {
      if connection.can_send?
        connection.send do |writer|
          writer.sym(:find)
          writer.str(Settings::GAME_VERSION)
          writer.int(partner_id.to_i)  # Convert to integer for server
          writer.str($player.name)
          writer.int($player.id)
          writer.sym($player.online_trainer_type)
          writer.int($player.online_win_text)
          writer.int($player.online_lose_text)
          CableClub::write_party(writer)
        end
        break
      else
        if partner_id == "00000"
          pbDisplayDots(_INTL("Connecting to matchmaking service..."))
        else
          pbDisplayDots(_ISPRINTF("Your ID: {1:05d}\nConnecting for direct link", $player.public_ID($player.id)))
        end
      end
    }
    await_partner(connection, partner_id)
  end
  
  # Updated await_partner method with different messages for random vs direct
  def await_partner(connection, partner_id = nil)
    partner_found = false
    change_state(:await_partner) {  
      if partner_id == "00000"
        pbDisplayDots(_INTL("Looking for any available trainer..."))
      else
        pbDisplayDots(_ISPRINTF("Searching for trainer with ID: {1}", partner_id))
      end
      
      connection.update do |record|
        case (type = record.sym)
        when :found
          @client_id = record.int
          @partner_name = record.str
          @partner_trainertype = record.sym
          @partner_win_text = record.int
          @partner_lose_text = record.int
          @partner_party = CableClub::parse_party(record)
          @server_rules = CableClub::parse_battle_rules(record)
          partner_found = true
        else
          raise "Unknown message: #{type}"
        end
      end
      break if partner_found
    }
    
    if partner_found
      if partner_id == "00000"
        pbDisplay(_INTL("Trainer {1} found through matchmaking!", @partner_name))
      else
        pbDisplay(_INTL("{1} connected!", @partner_name))
      end
      
      if @client_id == 0
        choose_activity(connection)
      else
        await_choose_activity(connection)
      end
    end
  end
end