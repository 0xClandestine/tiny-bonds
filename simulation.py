from uniplot import plot

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
    elapsed_time_since_last_update,
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
                elapsed_time_since_last_update + i,
                half_life,
                level_bips
            )
        ) / 1e18

        for i in range(half_life * half_lives)
    ]

    plot(x, color=True, title="Bond Price Forecast", lines=True, y_unit=" wad")

    print("Starting Price: ", x[0])
    print("Ending Price: ", x[-1])

terminal_plot(50e18, 100e18, 50e18, 0, 1, 7, 9000)