# example:
# python3 simulation.py --available-debt 50000000000000000000 --virtual-input 100000000000000000000 --virtual-output 50000000000000000000 --half-life 1 --half-lives 7 --level-bips 9000

from uniplot import plot
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--available-debt', type=int, required=True)
parser.add_argument('--virtual-input', type=int, required=True)
parser.add_argument('--virtual-output', type=int, required=True)
parser.add_argument('--half-life', type=int, required=True)
parser.add_argument('--half-lives', type=int, required=True)
parser.add_argument('--level-bips', type=int, required=True)
args = parser.parse_args()

def spot_price(
    available_debt,
    virtual_input,
    virtual_output,
    elapsed_time_since_last_update,
    half_life,
    level_bips
):
    return int(
        1e18 * exponential_to_level(
            virtual_input, 
            elapsed_time_since_last_update, 
            half_life, 
            level_bips
        ) // (available_debt + virtual_output)
    )

def exponential_to_level(x, elapsed, half_life, level_bips):
    z = int(x) >> (elapsed // half_life)
    z -= (z * (elapsed % half_life) // half_life) >> 1
    z += (x - z) * level_bips // 1e4
    return int(z)

def terminal_plot(
    available_debt,
    virtual_input,
    virtual_output,
    half_life,
    half_lives,
    level_bips
):
    x = [
        int(
            spot_price(
                available_debt,
                virtual_input,
                virtual_output,
                i,
                half_life,
                level_bips
            )
        ) / 1e18

        for i in range(half_life * half_lives)
    ]

    plot(x, color=True, title="Bond Price Forecast", lines=True, y_unit=" wad")

    print("Starting Price: ", x[0])
    print("Ending Price: ", x[-1])

terminal_plot(args.available_debt, args.virtual_input, args.virtual_output, args.half_life, args.half_lives, args.level_bips)