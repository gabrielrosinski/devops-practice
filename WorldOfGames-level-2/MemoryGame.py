from typing import List
import os
import random
import sys
import time


class MemoryGame():

    def __init__(self, difficulty):
        self.difficulty = difficulty
        
    def generate_sequence(self):
        amount = self.difficulty
        self.numbers = [random.randint(1, 101) for _ in range(amount)]
    
    def _clear_screen(self) -> None:
        """Best-effort clear/hide output so the user can’t see the sequence."""
        if sys.stdout.isatty():
            os.system("cls" if os.name == "nt" else "clear")
        else:
            print("\n" * 50)
    
    def show_sequence_briefly(self, seconds: float = 0.7) -> None:
        """Show the generated sequence briefly, then hide it."""
        print("Memorize this sequence:")
        print(" ".join(map(str, self.numbers)))
        time.sleep(seconds)
        self._clear_screen()            
        
    def get_list_from_user(self):
        while True:
            raw = input(f"Enter the {self.difficulty} numbers you remember, "
                        "space-separated (order matters):\n").strip()
            parts = raw.split()
            if len(parts) != self.difficulty:
                print(f"Please enter exactly {self.difficulty} numbers.")
                continue
            try:
                guesses = [int(p) for p in parts]
                return guesses
            except ValueError:
                print("All entries must be integers. Try again.")
    
    def is_list_equal(self, a: List[int], b: List[int]) -> bool:
        return a == b
    
    def play(self):
        self.generate_sequence()
        self.show_sequence_briefly(0.7)
        guesses = self.get_list_from_user()
        won = self.is_list_equal(guesses, self.numbers)
        return won
    