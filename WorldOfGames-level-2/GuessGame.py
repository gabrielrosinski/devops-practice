import random


class GuessGame():
    
    def __init__(self, difficulty):
        self.secret_number = 0
        self.difficulty = difficulty
    
    def generate_number(self):
        self.secret_number = random.randint(1, self.difficulty)
    
    def get_guess_from_user(self):
         while True:
            try:
                guess = int(input(f"Pick a number between 1 and {self.difficulty}: "))
                if 1 <= guess <= self.difficulty:
                    return guess
                else:
                    print(f"Please enter a number between 1 and {self.difficulty}.")
            except ValueError:
                print("That’s not a valid number. Try again.")
    
    def compare_results(self):
        return self.secret_number == self.get_guess_from_user()
    
    def play(self):
        self.generate_number()
        return self.compare_results()


    