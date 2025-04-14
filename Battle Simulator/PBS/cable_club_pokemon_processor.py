import argparse
from collections import defaultdict
import configparser
import os.path
import re
"""
#-------------------------------
[BULBASAUR]
Name = Bulbasaur
Types = GRASS,POISON
BaseStats = 45,49,49,45,65,65
GenderRatio = FemaleOneEighth
GrowthRate = Parabolic
BaseExp = 64
EVs = SPECIAL_ATTACK,1
CatchRate = 45
Happiness = 50
Abilities = OVERGROW
HiddenAbilities = CHLOROPHYLL
Moves = 1,GROWL,1,TACKLE,3,VINEWHIP,6,GROWTH,9,LEECHSEED,12,RAZORLEAF,15,POISONPOWDER,15,SLEEPPOWDER,18,SEEDBOMB,21,TAKEDOWN,24,SWEETSCENT,27,SYNTHESIS,30,WORRYSEED,33,POWERWHIP,36,SOLARBEAM
TutorMoves = ACIDSPRAY,BODYSLAM,BULLETSEED,CHARM,CURSE,DOUBLEEDGE,ENDURE,ENERGYBALL,FACADE,FALSESWIPE,GIGADRAIN,GRASSKNOT,GRASSPLEDGE,GRASSYGLIDE,GRASSYTERRAIN,HELPINGHAND,KNOCKOFF,LEAFSTORM,MAGICALLEAF,PROTECT,REST,SEEDBOMB,SLEEPTALK,SLUDGEBOMB,SOLARBEAM,SUBSTITUTE,SUNNYDAY,SWORDSDANCE,TAKEDOWN,TOXIC,TRAILBLAZE,VENOSHOCK,WEATHERBALL,TERABLAST
EggMoves = CURSE,INGRAIN,PETALDANCE,TOXIC
EggGroups = Monster,Grass
HatchSteps = 5120
Height = 0.7
Weight = 6.9
Color = Green
Shape = Quadruped
Habitat = Grassland
Category = Seed
Pokedex = Bulbasaur can be seen napping in bright sunlight. There is a seed on its back. By soaking up the sun's rays, the seed grows progressively larger.
Generation = 1
Evolutions = IVYSAUR,Level,16
#-------------------------------
"""


class EvolutionGraph:
    def __init__(self):
        self._graph = defaultdict(set)
        self._base_mons = set()
    
    def add_evolution(self, prevo, evo):
        self._graph[prevo].add((evo, False))
        self._graph[evo].add((prevo, True))
        self._base_mons.add(prevo)
        if any(e[1] for e in self._graph[prevo]):
            self._base_mons.discard(prevo)
    
    def get_directly_connected_mons(self, base):
        return {e[0] for e in self._graph[base] if not e[1]}
        
    def flatten_families(self, mode):
        families = {}
        if mode == 'shared':
            for base in self._base_mons:
                families[base] = list(self.depth_first_search(base))
        elif mode == 'propagate':
            for base in self._base_mons:
                families[base] = self.get_directly_connected_mons(base)
            for base in (self._graph.keys() - self._base_mons):
                families[base] = self.get_directly_connected_mons(base)
        families.pop('', None)
        return families
    
    def depth_first_search(self, base):
        seen = set()
        def loop(b):
            if b and b not in seen:
                seen.add(b)
                yield b
                for mon in self._graph[b]:
                    if mon[0] and not mon[1]:
                        yield from loop(mon[0])
        return loop(base)


def parse_pokemon_data(file_path):
    """Parse Pokemon data in the format with [POKEMON] headers and attribute = value pairs."""
    pokemon_data = {}
    current_section = None
    line_number = 0
    
    try:
        with open(file_path, 'r', encoding='utf-8-sig') as f:
            print(f"Opened file: {file_path}")
            content = f.readlines()
            
            for line in content:
                line_number += 1
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                    
                # Check if this is a section header [POKEMON]
                section_match = re.match(r'\[([A-Z0-9_,]+)\]', line, re.IGNORECASE)
                if section_match:
                    current_section = section_match.group(1).upper()
                    pokemon_data[current_section] = {}
                    continue
                    
                # Parse key=value pairs
                if current_section and '=' in line:
                    key, value = [part.strip() for part in line.split('=', 1)]
                    pokemon_data[current_section][key] = value
    except Exception as e:
        print(f"Error parsing {file_path} at line {line_number}: {str(e)}")
        print(f"Line content: {line if 'line' in locals() else 'Unknown'}")
        raise
    
    print(f"Found {len(pokemon_data)} Pokémon entries in {file_path}")
    return pokemon_data


def organize_evo_families(input_files, forms_files=None):
    evos = EvolutionGraph()
    
    # Process main Pokemon files
    for file_path in input_files:
        pokemon_data = parse_pokemon_data(file_path)
        
        for internal_name, species in pokemon_data.items():
            if "Evolutions" in species and species['Evolutions']:
                evo_data = species["Evolutions"].split(",")
                # Each evolution is specified as TARGET,METHOD,LEVEL
                for i in range(0, len(evo_data), 3):
                    if i < len(evo_data):
                        target = evo_data[i]
                        evos.add_evolution(internal_name, target)
    
    # Process form files if provided
    if forms_files:
        for file_path in forms_files:
            pokemon_data = parse_pokemon_data(file_path)
            
            for section, fspecies in pokemon_data.items():
                # Handle the form name format: BASE,FORM or BASE FORM
                skey = section.replace(',', '-').replace(' ', '-')
                internal_name, _, _ = skey.partition('-')
                
                if "Evolutions" in fspecies and fspecies['Evolutions']:
                    evo_data = fspecies["Evolutions"].split(",")
                    for i in range(0, len(evo_data), 3):
                        if i < len(evo_data):
                            target = evo_data[i]
                            evos.add_evolution(internal_name, target)
    
    return evos


def process_move_list(moves_str):
    """Extract move names from various move list formats."""
    if not moves_str:
        return set()
    
    try:
        # For level-up moves in format "1,TACKLE,3,GROWL,..." - extract just the moves
        if moves_str and ',' in moves_str:
            parts = moves_str.split(',')
            # Check if this is a level-up format (numbers alternating with moves)
            if parts and parts[0].strip().isdigit():
                # Every even-indexed item (1-based) should be a move
                return {parts[i].strip() for i in range(1, len(parts), 2) if i < len(parts) and parts[i].strip()}
            # Otherwise, it's a simple comma-separated list
            return {m.strip() for m in parts if m.strip()}
        
        # For single move
        return {moves_str.strip()} if moves_str.strip() else set()
    except Exception as e:
        print(f"Error processing move list: {str(e)}")
        print(f"Problematic move string: {moves_str}")
        return set()


def generate_server_pokemon_PBS(mode, input_files, output_file, forms_files=None, tm_file=None):
    output_parser = configparser.ConfigParser(default_section=None)
    
    # Get evolution families if needed
    evo_fams = None
    if mode == 'propagate' or mode == 'shared':
        evo_fams = organize_evo_families(input_files, forms_files)
    
    # Process main Pokemon files
    pokemon_data = {}
    for file_path in input_files:
        print(f"Processing main file: {file_path}")
        pokemon_data.update(parse_pokemon_data(file_path))
    
    # Create sections for each Pokemon
    for internal_name, species in pokemon_data.items():
        output_parser.add_section(internal_name)
        
        # Set internal number (same as name in this format)
        output_parser.set(internal_name, 'internal_number', internal_name)
        output_parser.set(internal_name, 'forms', '0')
        
        # Handle gender ratio
        if 'GenderRatio' in species:
            output_parser.set(internal_name, 'gender_ratio', species['GenderRatio'])
        else:
            # Default gender ratio if not specified
            output_parser.set(internal_name, 'gender_ratio', 'FemaleOneEighth')
        
        # Process abilities
        abilities = set()
        if 'Abilities' in species:
            abilities.update(species['Abilities'].split(','))
        if 'HiddenAbilities' in species:
            abilities.update(species['HiddenAbilities'].split(','))
        
        output_parser.set(internal_name, 'abilities', ",".join(abilities))
        
        # Process moves
        moves = set()
        
        # Level-up moves
        if 'Moves' in species:
            moves.update(process_move_list(species['Moves']))
        
        # Egg moves
        if 'EggMoves' in species:
            moves.update(process_move_list(species['EggMoves']))
        
        # Tutor moves
        if 'TutorMoves' in species:
            moves.update(process_move_list(species['TutorMoves']))
        
        output_parser.set(internal_name, 'moves', ",".join(moves))
    
    # Process form files if provided
    if forms_files:
        form_count = 0
        for file_path in forms_files:
            print(f"Processing form file: {file_path}")
            try:
                form_data = parse_pokemon_data(file_path)
                form_count += len(form_data)
                
                for section, fspecies in form_data.items():
                    # Handle the form name format: BASE,FORM or BASE FORM
                    skey = section.replace(',', '-').replace(' ', '-')
                    internal_name, _, f_num = skey.partition('-')
                    
                    print(f"  Found form: {section} -> base: {internal_name}, form: {f_num}")
                    
                    # Skip if base form doesn't exist
                    if internal_name not in output_parser:
                        print(f"  Warning: Base form {internal_name} not found, skipping")
                        continue
                    
                    # Update form numbers
                    form_nums = output_parser[internal_name]['forms'].split(',')
                    if f_num and f_num not in form_nums:
                        form_nums.append(f_num)
                        output_parser.set(internal_name, 'forms', ','.join(form_nums))
                        print(f"  Updated forms for {internal_name}: {','.join(form_nums)}")
                    
                    # Update abilities
                    abilities = set()
                    if output_parser[internal_name]['abilities']:
                        abilities.update(output_parser[internal_name]['abilities'].split(','))
                    if 'Abilities' in fspecies:
                        abilities.update(fspecies['Abilities'].split(','))
                    if 'HiddenAbilities' in fspecies:
                        abilities.update(fspecies['HiddenAbilities'].split(','))
                    output_parser.set(internal_name, 'abilities', ",".join(abilities))
                    
                    # Update moves
                    moves = set()
                    if output_parser[internal_name]['moves']:
                        moves.update(output_parser[internal_name]['moves'].split(','))
                    if 'Moves' in fspecies:
                        moves.update(process_move_list(fspecies['Moves']))
                    if 'EggMoves' in fspecies:
                        moves.update(process_move_list(fspecies['EggMoves']))
                    if 'TutorMoves' in fspecies:
                        moves.update(process_move_list(fspecies['TutorMoves']))
                    output_parser.set(internal_name, 'moves', ",".join(moves))
            except Exception as e:
                print(f"Error processing form file {file_path}: {str(e)}")
        
        print(f"Processed {form_count} forms from {len(forms_files)} files")
    
    # Process TM file if provided
    if tm_file:
        tm_data = {}
        current_move = None
        
        with open(tm_file, 'r', encoding='utf-8-sig') as tm_pbs:
            for line in tm_pbs:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                    
                # Check for [MOVE] header
                move_match = re.match(r'\[([A-Z_]+)\]', line)
                if move_match:
                    current_move = move_match.group(1)
                    continue
                
                # If we have a current move, add it to the Pokemon's moves
                if current_move:
                    for pokemon_name in line.split(','):
                        pokemon_name = pokemon_name.strip()
                        if pokemon_name and pokemon_name in output_parser:
                            moves = set(output_parser[pokemon_name]['moves'].split(','))
                            moves.add(current_move)
                            output_parser.set(pokemon_name, 'moves', ",".join(moves))
    
    # Process evolution families if needed
    if evo_fams:
        families = evo_fams.flatten_families(mode)
        for base, family in families.items():
            if base not in output_parser:
                continue
                
            if mode == 'propagate':
                # Copy moves from base to evolutions
                base_moves = set(output_parser[base]['moves'].split(','))
                for mon in family:
                    if mon != base and mon in output_parser:
                        moves = set(output_parser[mon]['moves'].split(','))
                        moves.update(base_moves)
                        output_parser.set(mon, 'moves', ",".join(moves))
                        
            elif mode == 'shared':
                # Share all moves across evolution family
                all_moves = set()
                for mon in [base] + list(family):
                    if mon in output_parser:
                        all_moves.update(output_parser[mon]['moves'].split(','))
                
                # Apply shared moveset to all family members
                for mon in [base] + list(family):
                    if mon in output_parser:
                        output_parser.set(mon, 'moves', ",".join(all_moves))
    
    # Write output file
    with open(output_file, 'w') as configfile:
        print(f"Writing output to {output_file}")
        print(f"Total Pokémon: {len(output_parser.sections())}")
        output_parser.write(configfile)
    
    # Debug: Print the first few sections of the output file
    print("\nSample of processed Pokémon:")
    for i, section in enumerate(output_parser.sections()):
        if i >= 5:  # Just print the first 5 for brevity
            break
        print(f"[{section}]")
        print(f"  forms = {output_parser[section]['forms']}")
        print(f"  abilities = {output_parser[section]['abilities']}")
        
    return output_parser  # Return for testing/inspection


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='A preprocessor that converts game PBS files into a format acceptable for Cable Club\'s Server.')
    parser.add_argument('--mode', choices=['simple', 'propagate', 'shared'], default='simple',
                       help='The method used in processing the PBS file. simple is a direct conversion, propagate copies movesets down an evolution chain, shared gives the same moveset to all members of an evolutionary family.')
    parser.add_argument('-o', '--output_file', default='server_pokemon.txt',
                       help='The output name of the file. Cable Club expects a pokemon_server.txt file.')
    parser.add_argument('-pf', '--forms_files', nargs='+',
                       help='If provided, will combine the data from the forms files into the base form data.')
    parser.add_argument('-tm', '--tm_file',
                       help='If provided, will combine the moves data with the main pokemon.txt PBS file')
    parser.add_argument('-gen9', '--gen9_pack', default='pokemon_base_Gen_9_Pack.txt',
                       help='Path to the Gen 9 pack file to include in processing (default: pokemon_base_Gen_9_Pack.txt)')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Enable verbose output for debugging')
    parser.add_argument('input_files', nargs='+',
                       help='The pokemon.txt files to convert.')
    
    args = parser.parse_args()
    
    # Enable verbose output if requested
    if args.verbose:
        print("Verbose mode enabled")
    
    # Check if Gen 9 pack file exists and add it to input files if it does
    if os.path.exists(args.gen9_pack):
        print(f"Including Gen 9 pack file: {args.gen9_pack}")
        args.input_files.append(args.gen9_pack)
    else:
        print(f"Warning: Gen 9 pack file '{args.gen9_pack}' not found. Continuing without it.")
    
    # Add default form files if not explicitly provided
    if not args.forms_files:
        args.forms_files = []
    
    # Check for pokemon_forms.txt
    if os.path.exists('pokemon_forms.txt'):
        print("Including pokemon_forms.txt")
        args.forms_files.append('pokemon_forms.txt')
    else:
        print("Warning: 'pokemon_forms.txt' not found.")
    
    # Check for pokemon_forms_Gen_9_Pack.txt
    if os.path.exists('pokemon_forms_Gen_9_Pack.txt'):
        print("Including pokemon_forms_Gen_9_Pack.txt")
        args.forms_files.append('pokemon_forms_Gen_9_Pack.txt')
    else:
        print("Warning: 'pokemon_forms_Gen_9_Pack.txt' not found.")
    
    # Display the final list of form files
    if args.forms_files:
        print(f"Using form files: {', '.join(args.forms_files)}")
    else:
        print("No form files found or specified")
    
    # Process the files
    result = generate_server_pokemon_PBS(args.mode, args.input_files, args.output_file, args.forms_files, args.tm_file)
    
    # Print a summary of the results
    print(f"\nProcessing complete. Generated {args.output_file} with {len(result.sections())} Pokémon entries.")
