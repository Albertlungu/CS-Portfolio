# The-Sleepwalkers
DAYDREAM RAHHHHHHHHH (Eason YANG, Sebastian WU, Albert LUNGU)


# The Sleepwalkers

![Game Screenshot](assets/main/title_page.png)

## Overview

**The Sleepwalkers** is a 2D top-down adventure game built in **Python** using **Pygame**, designed for browser play via **pygbag**. Players control a hero exploring a mystical world to rescue a princess trapped in a secret room. The game combines exploration, puzzle-solving, and mini-games, including platforming and a laser labyrinth challenge.

---

## Gameplay

1. **Title Screen**  
   - Start the game by clicking the **Play** button.

2. **Character Selection**  
   - Choose your hero from four unique sprites. Each has the same gameplay mechanics.  

3. **Main Map**  
   - Navigate a large world with top-down movement.  
   - Only **walkable areas** (white pixels in the path image) are accessible.  
   - The camera follows the player as they move.  

4. **Mini-Games & Challenges**  
   - **Platformer Entrance**: Tests timing and precision.  
   - **Laser Labyrinth**: Requires collecting the `"platform_key"` to enter.  
   - **Room with Princess**: Requires the `"lab_key"` to enter and rescue the princess.  

5. **Princess Rescue**  
   - Once rescued, the princess follows the player as a trailing sprite.  
   - Exiting the room after rescuing her triggers the **win screen**.

6. **Win Condition**  
   - Successfully escort the princess out of the room and see the victory screen.

---

## Event & Team

This game was created for **Daydream Ottawa 2025**, a student-led hackathon celebrating creativity and innovation in coding and digital storytelling.  

- **Team Size:** 3 members  
- **Role:** Lead Developer & Backend Programmer  
  - Implemented ** game mechanics**, **event handling**, and **mini-games**.  
  - Managed 26 out of 27 commits in the repository.  
- **Team Contributions:**  
  - Sprites and visual assets created by two team members.  

**Repository:** [https://github.com/Albertlungu/The-Sleepwalkers.git](https://github.com/Albertlungu/The-Sleepwalkers.git)

---

## Installation & Running Locally

1. Clone the repository:  
   ```bash
   git clone https://github.com/Albertlungu/The-Sleepwalkers.git
   cd The-Sleepwalkers
