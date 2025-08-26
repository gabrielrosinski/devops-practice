import asyncio
import aiohttp
import random

class CurrencyRouletteGame():

    def __init__(self, difficulty: int):
        if not 1 <= difficulty <= 5:
            raise ValueError("difficulty must be between 1 and 5")
        self.difficulty = difficulty
    
    async def get_usd_to_ils_rate(self) -> float:
        url = "https://api.frankfurter.app/latest?from=USD&to=ILS"
        timeout = aiohttp.ClientTimeout(total=10)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.get(url) as resp:
                resp.raise_for_status()
                data = await resp.json()
                return float(data["rates"]["ILS"])

    def get_money_interval(self, amount_usd: float, rate: float) -> tuple[float, float]:
        t = amount_usd * rate
        margin = 5 - self.difficulty  
        return (t - margin, t + margin) #(t - (5 - d), t + (5 - d))
    
    def get_guess_from_user(self, amount_usd: int) -> float:
        while True:
            try:
                s = input(f"How many ILS is {amount_usd} USD? ")
                return float(s)
            except ValueError:
                print("Please enter a valid number (you can use a decimal point).")
                
    async def play(self):
        usd_amount = random.randint(1, 100)
        try:
            rate = await self.get_usd_to_ils_rate()
        except Exception as e:
            print(f"Could not fetch exchange rate: {e}")
            return False

        low, high = await self.get_money_interval(usd_amount, rate)
        guess = self.get_guess_from_user(usd_amount)
        won = low <= guess <= high
        return won


if __name__ == "__main__":
    game = CurrencyRouletteGame(difficulty=3)
    print(asyncio.run(game.play()))