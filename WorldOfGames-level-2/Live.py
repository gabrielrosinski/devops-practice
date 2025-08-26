
from CurrencyRouletteGame import CurrencyRouletteGame
from GuessGame import GuessGame
from MemoryGame import MemoryGame


def welcome(name):
    return f"Hello {name} and welcome to the World of Games (WoG)\nHere you can find many cool games to play"

def load_game():
    result = False
    
    while True:
        try:
            gameNumber = int(input("""Please choose a game to play:
1. Memory Game - a sequence of numbers will appear for 1 second and you have to guess it back.
2. Guess Game - guess a number and see if you chose like the computer.
3. Currency Roulette - Currency Roulette - try and guess the value of a random amount of USD in ILS.
"""))
            if gameNumber < 1 or gameNumber > 3:
                print("That’s not a valid number. Try again.\n")
                print("Please enter a number between 1 and 3")
            else:
                break
        except ValueError:
            print("Invalid input. Please enter a whole number.")
    
    levelOfDifficulty = int(input("Please choose game difficulty from 1 to 5: "))
    
    while True:
        levelOfDifficulty = int(input("Pick a number between 1 and 5: "))
        if levelOfDifficulty < 1 or levelOfDifficulty > 5:
            print("That’s not a valid number. Try again.\n")
            print("Please enter a number between 1 and 5")
        else:
            break
    
    match gameNumber:
        case 1:
            m = MemoryGame(levelOfDifficulty)
            result = m.play()
        case 2:
            g = GuessGame(levelOfDifficulty)
            result = g.play()
        case 3:
            c = CurrencyRouletteGame(levelOfDifficulty)
            result = c.play()
    print("You won!" if result else "You lost!")
            
def main():
    name = input("\n\nWhat is your name? ")
    print(welcome(name))
    load_game()

if __name__ == "__main__":
    main()