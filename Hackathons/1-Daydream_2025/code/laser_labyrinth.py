# laser_labyrinth.py

import pygame
from code.game_state import player_keys
import os

WIDTH, HEIGHT = 1200, 800
FPS = 60
laser_color = (214, 60, 60)

class Laser:
    def __init__(self, x, y, w, h, speed, direction='horizontal'):
        self.rect = pygame.Rect(x, y, w, h)
        self.speed = speed
        self.direction = direction  # 'horizontal' or 'vertical'

    def update(self):
        if self.direction == 'horizontal':
            self.rect.x += self.speed
            if self.rect.left < 0 or self.rect.right > WIDTH:
                self.speed *= -1
        else:
            self.rect.y += self.speed
            if self.rect.top < 0 or self.rect.bottom > HEIGHT:
                self.speed *= -1

def load_image(path, size=None):
    if os.path.exists(path):
        img = pygame.image.load(path).convert_alpha()
        if size:
            img = pygame.transform.scale(img, size)
        return img
    else:
        print(f"File not found: {path}")
        return None

def fade_out(screen, duration=0.5):
    """Fade out effect."""
    clock = pygame.time.Clock()
    overlay = pygame.Surface((WIDTH, HEIGHT))
    overlay.fill((0, 0, 0))
    steps = int(duration * FPS)
    for i in range(steps):
        alpha = int((i / steps) * 255)
        overlay.set_alpha(alpha)
        screen.blit(overlay, (0, 0))
        pygame.display.flip()
        clock.tick(FPS)

def run_laser_labyrinth(screen, player_sprite):
    global player_keys
    clock = pygame.time.Clock()
    running = True

    # Load background
    background = load_image("assets/laser_labyrinth/laser_map.png", (WIDTH, HEIGHT))
    hardcore_heart = load_image("assets/main/hardcore_heart.png", (50,50))

    # Player start position
    sprite_width = player_sprite.get_width()
    sprite_height = player_sprite.get_height()
    start_pos = (100, HEIGHT - 150)
    player_rect = pygame.Rect(*start_pos, sprite_width, sprite_height)

    # Hitbox smaller than sprite for accurate collision
    HITBOX_PADDING_X = 10
    HITBOX_PADDING_Y = 10

    # Player speed
    speed = 5

    # Lasers
    lasers = [
        Laser(100, 50, 200, 20, 3, 'horizontal'),
        Laser(400, 150, 20, 200, 2, 'vertical'),
        Laser(200, 400, 300, 20, 4, 'horizontal'),
        Laser(600, 100, 20, 300, 3, 'vertical')
    ]

    # Exit
    exit_rect = pygame.Rect(WIDTH - 100, 50, 50, 50)

    while running:
        clock.tick(FPS)
        keys = pygame.key.get_pressed()
        dx, dy = 0, 0
        if keys[pygame.K_LEFT]: dx = -speed
        if keys[pygame.K_RIGHT]: dx = speed
        if keys[pygame.K_UP]: dy = -speed
        if keys[pygame.K_DOWN]: dy = speed

        # Move player
        player_rect.x += dx
        player_rect.y += dy

        # Keep player in screen bounds
        player_rect.x = max(0, min(player_rect.x, WIDTH - player_rect.width))
        player_rect.y = max(0, min(player_rect.y, HEIGHT - player_rect.height))

        # Hitbox for collisions
        hitbox = pygame.Rect(
            player_rect.x + HITBOX_PADDING_X,
            player_rect.y + HITBOX_PADDING_Y,
            player_rect.width - 2 * HITBOX_PADDING_X,
            player_rect.height - 2 * HITBOX_PADDING_Y
        )

        # Update lasers
        for laser in lasers:
            laser.update()

        # Check collisions with lasers
        if any(hitbox.colliderect(laser.rect) for laser in lasers):
            player_keys = {k: False for k in player_keys}
            fade_out(screen, duration=0.5)
            return "restart_adventure"    

        # Check if reached exit
        if hitbox.colliderect(exit_rect):
            player_keys["lab_key"] = True  # Give the lab key
            fade_out(screen, duration=0.5)  # Fade (LOW TAPER FADEEEEEEE)
            return "main"

        # Draw stuff
        if background:
            screen.blit(background, (0, 0))
        else:
            screen.fill((0, 0, 0))  # Fallback background

        for laser in lasers:
            pygame.draw.rect(screen, laser_color, laser.rect, border_radius= 15)  # Red lasers
        pygame.draw.rect(screen, (0, 255, 0), exit_rect)  # Green exit
        screen.blit(player_sprite, (player_rect.x, player_rect.y))

        # Handle events
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return "quit"

        pygame.display.flip()