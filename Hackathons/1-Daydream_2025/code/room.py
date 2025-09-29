import pygame
import code.game_state
import os
import sys

FPS = 60

ROOM_PATH = "assets/room/room.jpg"
PRINCESS_PATH = "assets/room/princess.png"

def load_image(path, size=None):
    if os.path.exists(path):
        img = pygame.image.load(path).convert_alpha()
        if size:
            img = pygame.transform.scale(img, size)
        return img
    else:
        print(f"File not found: {path}")
        return None

def ask_riddle(screen, riddle_text, correct_answer, font_size=28):
    """
    Display a riddle and get player's text input. Returns True if correct.
    """
    clock = pygame.time.Clock()
    input_text = ""
    font = pygame.font.Font(
        "assets/main/PixemonTrialRegular-p7nLK.ttf",
        font_size
    )
    running = True
    result = False

    while running:
        clock.tick(FPS)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_RETURN:
                    if input_text.strip().lower() == correct_answer.lower():
                        result = True
                        running = False
                    else:
                        input_text = ""  # reset for retry
                elif event.key == pygame.K_BACKSPACE:
                    input_text = input_text[:-1]
                else:
                    input_text += event.unicode

        # Draw riddle screen
        screen.fill((50, 50, 150))
        # Wrap riddle text if too long
        def wrap_text(text, font, max_width):
            words = text.split(' ')
            lines = []
            current_line = ""
            for word in words:
                test_line = current_line + " " + word if current_line else word
                if font.size(test_line)[0] <= max_width:
                    current_line = test_line
                else:
                    lines.append(current_line)
                    current_line = word
            if current_line:
                lines.append(current_line)
            return lines

        lines = wrap_text(riddle_text, font, screen.get_width() - 100)
        for i, line in enumerate(lines):
            text_surf = font.render(line, True, (255, 255, 255))
            screen.blit(text_surf, (50, 50 + i * (font_size + 5)))

        # Draw input box
        input_box = pygame.Rect(50, 150 + len(lines)*(font_size+5), screen.get_width() - 100, 40)
        pygame.draw.rect(screen, (255,255,255), input_box, 2)
        input_surf = font.render(input_text, True, (255,255,255))
        screen.blit(input_surf, (input_box.x + 5, input_box.y + 5))

        pygame.display.flip()
    
    return result

def fade_out(screen, duration=0.5):
    """Fade the screen to black."""
    clock = pygame.time.Clock()
    fade_surface = pygame.Surface(screen.get_size())
    fade_surface.fill((0, 0, 0))
    steps = int(duration * FPS)
    for i in range(steps):
        alpha = int((i / steps) * 255)
        fade_surface.set_alpha(alpha)
        screen.blit(fade_surface, (0, 0))
        pygame.display.flip()
        clock.tick(FPS)

def run_room(screen, player_sprite):
    if not code.game_state.player_keys.get("lab_key", False):
        return "main"

    clock = pygame.time.Clock()
    running = True
    screen_width, screen_height = screen.get_size()

    # Load and scale room background to fill the screen
    background = pygame.image.load(ROOM_PATH).convert()
    background = pygame.transform.scale(background, (screen_width, screen_height))

    # Load princess sprite
    princess_sprite = load_image(PRINCESS_PATH, (300, 300)).convert_alpha()
    princess_rect = princess_sprite.get_rect(center=(screen_width // 2 + 200, screen_height // 2))

    # Load fairy sprite
    fairy_sprite = load_image("assets/room/fairy.png", (150, 150))
    fairy_rect = fairy_sprite.get_rect(topleft=(50, 50))

    # Player start position
    sprite_width = player_sprite.get_width()
    sprite_height = player_sprite.get_height()
    player_rect = pygame.Rect(100, screen_height - 150, sprite_width, sprite_height)

    HITBOX_PADDING_X, HITBOX_PADDING_Y = 10, 10
    speed = 5

    # Room exit (bottom center)
    exit_radius = 55
    exit_rect = pygame.Rect(screen_width // 2 - 140, screen_height - 50 - exit_radius, exit_radius * 2, exit_radius * 2)

    # Initialize princess trail
    if code.game_state.pink_pos == [0, 0]:
        code.game_state.pink_pos[0] = player_rect.x - 10
        code.game_state.pink_pos[1] = player_rect.y - 10

    # Riddle state
    riddle_given = False
    riddle_solved = False
    riddle_text = "I speak without a mouth and hear without ears. I have nobody, but I come alive with wind. What am I?"
    correct_answer = "echo"

    # Font for riddle/dialogue
    font = pygame.font.Font(
        "assets/main/PixemonTrialRegular-p7nLK.ttf", 
        28
    )

    input_text = ""
    input_active = False

    while running:
        clock.tick(FPS)
        keys = pygame.key.get_pressed()
        dx = dy = 0
        if keys[pygame.K_LEFT]: dx = -speed
        if keys[pygame.K_RIGHT]: dx = speed
        if keys[pygame.K_UP]: dy = -speed
        if keys[pygame.K_DOWN]: dy = speed

        # Move player
        player_rect.x += dx
        player_rect.y += dy

        # Keep player in bounds
        player_rect.x = max(0, min(player_rect.x, screen_width - player_rect.width))
        player_rect.y = max(0, min(player_rect.y, screen_height - player_rect.height))

        # Player hitbox
        hitbox = pygame.Rect(
            player_rect.x + HITBOX_PADDING_X,
            player_rect.y + HITBOX_PADDING_Y,
            player_rect.width - 2*HITBOX_PADDING_X,
            player_rect.height - 2*HITBOX_PADDING_Y
        )

        # Check interaction with fairy
        if hitbox.colliderect(fairy_rect) and not riddle_given:
            input_active = True
            riddle_given = True

        # Handle text input for riddle
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return "quit"
            if input_active and event.type == pygame.KEYDOWN:
                if event.key == pygame.K_RETURN:
                    if input_text.strip().lower() == correct_answer.lower():
                        riddle_solved = True
                        input_active = False
                    input_text = ""
                elif event.key == pygame.K_BACKSPACE:
                    input_text = input_text[:-1]
                else:
                    input_text += event.unicode

        # Pick up princess only if riddle solved
        if hitbox.colliderect(princess_rect) and not code.game_state.player_has_pink and riddle_solved:
            code.game_state.player_has_pink = True

        # Move princess if picked up
        if code.game_state.player_has_pink:
            target_x = player_rect.x - 10
            target_y = player_rect.y - 10
            code.game_state.pink_pos[0] += (target_x - code.game_state.pink_pos[0]) * 0.3
            code.game_state.pink_pos[1] += (target_y - code.game_state.pink_pos[1]) * 0.3

        # Check exit
        if hitbox.colliderect(exit_rect):
            fade_out(screen, duration=0.5)
            return "main"

        # Draw everything
        screen.blit(background, (0, 0))
        screen.blit(player_sprite, (player_rect.x, player_rect.y))

        # Draw fairy
        screen.blit(fairy_sprite, fairy_rect.topleft)

        # Draw princess
        if code.game_state.player_has_pink:
            screen.blit(princess_sprite, (int(code.game_state.pink_pos[0]), int(code.game_state.pink_pos[1])))
        else:
            screen.blit(princess_sprite, princess_rect)

        # Draw exit
        # pygame.draw.circle(screen, (0, 255, 0), exit_rect.center, exit_radius)

        # Draw riddle input box if active
        if input_active:
            # Dialogue box
            box_rect = pygame.Rect(50, 220, screen_width - 100, 150)
            pygame.draw.rect(screen, (0, 0, 0), box_rect)
            pygame.draw.rect(screen, (255, 255, 255), box_rect, 3)

            # Riddle text (wrap if too long)
            def wrap_text(text, font, max_width):
                words = text.split(" ")
                lines = []
                current_line = ""
                for word in words:
                    test_line = current_line + " " + word if current_line else word
                    if font.size(test_line)[0] <= max_width:
                        current_line = test_line
                    else:
                        lines.append(current_line)
                        current_line = word
                if current_line:
                    lines.append(current_line)
                return lines

            lines = wrap_text(riddle_text, font, box_rect.width - 20)
            for i, line in enumerate(lines):
                line_surf = font.render(line, True, (255, 255, 255))
                screen.blit(line_surf, (box_rect.x + 10, box_rect.y + 10 + i*(font.get_height()+2)))

            # Input text
            input_surf = font.render(input_text, True, (255, 255, 0))
            screen.blit(input_surf, (box_rect.x + 10, box_rect.y + box_rect.height - 40))

        pygame.display.flip()