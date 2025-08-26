
def welcome(name):
    return f"Hello {name} and welcomne to the World of Games (WoG)\nHere you can find many cool games to play"

def load_game():
    gameNumber = int(input("""Please choose a game to play:
1. Memory Game - a sequence of numbers will appear for 1 second and you have to guess it back.
2. Guess Game - guess a number and see if you chose like the computer.
3. Currency Roulette - try and guess the value of a random amount of USD in ILS.
"""))
    
    if gameNumber < 1 or gameNumber > 3:
        print("Invalid game number. Please choose a number between 1 and 3.")
        return
    
    levelOfDifficulty = int(input("Please choose game difficulty from 1 to 5: "))
    
    if levelOfDifficulty < 1 or levelOfDifficulty > 5:
        print("Invalid difficulty level. Please choose a number between 1 and 5.")
        return
    
### for testing    
# def main():
#     name = input("What is your name? ")
#     print(welcome(name))
#     load_game()

# if __name__ == "__main__":
#     main()