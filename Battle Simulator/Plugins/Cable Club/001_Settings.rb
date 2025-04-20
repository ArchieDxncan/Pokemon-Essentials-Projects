module CableClub
  HOST = "kuba.miniduncan.net"
  PORT = 9999
  
  FOLDER_FOR_BATTLE_PRESETS = "OnlinePresets"
  
  ONLINE_TRAINER_TYPE_LIST = [
    [:POKEMONTRAINER_Brendan, :POKEMONTRAINER_May],
    [:POKEMONTRAINER_Red, :POKEMONTRAINER_Leaf],
    [:CHAMPION],
    [:LEADER_Blaine, :LEADER_Erika],
    [:LEADER_Blue, :LEADER_Misty],
    [:LEADER_Brock, :LEADER_Sabrina],
    [:LEADER_Giovanni, :LEADER_Lorelei],
    [:LEADER_Koga, :LEADER_Janine],
    [:LEADER_Misty, :LEADER_May],
    [:LEADER_Surge, :LEADER_Roxanne],
    [:AROMALADY, :BEAUTY],
    [:BIKER, :LADY],
    [:BIRDKEEPER, :LASS],
    [:BLACKBELT, :CRUSHGIRL],
    [:BUGCATCHER, :LEADER_Erika],
    [:BURGLAR, :LEADER_Misty],
    [:CAMPER, :PICNICKER],
    [:CHAMPION, :LEADER_Sabrina],
    [:CHANNELER, :COOLCOUPLE],
    [:COOLTRAINER_M, :COOLTRAINER_F],
    [:CUEBALL, :TUBER_F],
    [:ELITETOUR_Agatha, :LEADER_Lorelei],
    [:ELITETOUR_Bruno, :LEADER_Janine],
    [:ELITETOUR_Lance, :LEADER_May],
    [:ELITETOUR_Lorelei, :LEADER_Roxanne],
    [:ENGINEER, :POKEMANIAC_F],
    [:FISHERMAN, :SWIMMER_F],
    [:GAMBLER, :TWINS],
    [:GENTLEMAN, :YOUNGCOUPLE],
    [:HIKER, :YOUNSTER],
    [:JUGGLER, :PAINTER],
    [:PAINTER, :PICNICKER],
    [:POKEMANIAC, :POKEMANIAC_F],
    [:POKEMONRANGER_M, :POKEMONRANGER_F],
    [:PROFESSOR, :SCIENTIST_F],
    [:PSYCHIC_M, :PSYCHIC_F],
    [:RIVAL1, :RIVAL2],
    [:ROCKER, :ROCKBOSS],
    [:RUNNERMANIAC, :SCIENTIST],
    [:SAILOR, :SKISANDBOARDER],
    [:SUPERNERD, :TUBER_F],
    [:SWIMMER_M, :SWIMMER_F],
    [:TAMER, :TUBER_F],
    [:TEAMROCKET_M, :TEAMROCKET_F]
  ]
  
  ONLINE_WIN_SPEECHES_LIST = [
    _INTL("I won!"),
    _INTL("It's all thanks to my team."),
    _INTL("We secured the victory!"),
    _INTL("This battle was fun, wasn't it?")
  ]
  ONLINE_LOSE_SPEECHES_LIST = [
    _INTL("I lost..."),
    _INTL("I was confident in my team too."),
    _INTL("That was the one thing I wanted to avoid."),
    _INTL("This battle was fun, wasn't it?")
  ]
  
  ENABLE_RECORD_MIXER = false
  
  # If true, Sketch fails when used.
  # If false, Sketch is undone after battle
  DISABLE_SKETCH_ONLINE = true
end