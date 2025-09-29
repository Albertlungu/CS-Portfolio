# platformer.py
import pygame
import sys
import os
import code.game_state

WIDTH, HEIGHT = 1200, 800
FPS = 60
GRAVITY = 0.8
PLAYER_SPEED = 5
JUMP_STRENGTH = 15
WHITE = (255, 255, 255)

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
# ---------------- RUN FUNCTION ----------------
def run_platformer(screen, player_sprite=None):
    clock = pygame.time.Clock()

    # Load background
    bg_path = "assets/platformer/platform_map.png"
    if os.path.exists(bg_path):
        background = pygame.image.load(bg_path).convert_alpha()
        background = pygame.transform.scale(background, (WIDTH, HEIGHT))
    else:
        print(f"Background image not found: {bg_path}")
        background = pygame.Surface((WIDTH, HEIGHT))
        background.fill(WHITE)
    
    hardcore_heart_path = "assets/main/hardcore_heart.png"
    if os.path.exists(hardcore_heart_path):
        hardcore_heart = pygame.image.load(hardcore_heart_path).convert_alpha()
        hardcore_heart = pygame.transform.scale(hardcore_heart, (50, 50))
    else:
        hardcore_heart = None

    # Load platform image
    platform_img_path = "assets/platformer/platform_brown.png"
    if os.path.exists(platform_img_path):
        platform_img = pygame.image.load(platform_img_path).convert_alpha()
        platform_img = pygame.transform.scale(platform_img, (150, 50))
    else:
        print(f"Platform image not found: {platform_img_path}")
        platform_img = pygame.Surface((150, 50))
        platform_img.fill((100,50,0))

    # Load door image for goal
    door_img_path = "assets/platformer/door.png"
    if os.path.exists(door_img_path):
        door_img = pygame.image.load(door_img_path).convert_alpha()
        door_img = pygame.transform.scale(door_img, (100, 100))
    else:
        print(f"Door image not found: {door_img_path}")
        door_img = pygame.Surface((100, 100))
        door_img.fill((255, 223, 0))

    # ---------------- CLASSES ----------------
    class Player(pygame.sprite.Sprite):
        def __init__(self, x, y):
            super().__init__()
            if player_sprite:
                self.image = player_sprite
            else:
                self.image = pygame.Surface((50, 50))
                self.image.fill((50,150,255))
            self.rect = self.image.get_rect(topleft=(x, y))
            self.vel_y = 0
            self.on_ground = False

        def update(self, platforms):
            keys = pygame.key.get_pressed()
            if keys[pygame.K_LEFT]:
                self.rect.x -= PLAYER_SPEED
            if keys[pygame.K_RIGHT]:
                self.rect.x += PLAYER_SPEED

            self.vel_y += GRAVITY
            self.rect.y += self.vel_y

            self.on_ground = False
            for platform in platforms:
                if self.rect.colliderect(platform.rect):
                    if self.vel_y > 0:  # Falling
                        self.rect.bottom = platform.rect.top
                        self.vel_y = 0
                        self.on_ground = True
                    elif self.vel_y < 0:  # Jumping
                        self.rect.top = platform.rect.bottom
                        self.vel_y = 0

        def jump(self):
            if self.on_ground:
                self.vel_y = -JUMP_STRENGTH

    class Platform(pygame.sprite.Sprite):
        def __init__(self, x, y):
            super().__init__()
            self.image = platform_img
            self.rect = self.image.get_rect(topleft=(x, y))

    class Goal(pygame.sprite.Sprite):
        def __init__(self, x, y):
            super().__init__()
            self.image = door_img
            self.rect = self.image.get_rect(midbottom=(x + 75, y))  # Adjust to center on platform

    # ---------------- SPRITE GROUPS ----------------
    player = Player(100, 500)
    platforms = pygame.sprite.Group()
    all_sprites = pygame.sprite.Group()
    all_sprites.add(player)

    # ---------------- PLATFORM POSITIONS ----------------
    platform_positions = [
        (0, 550),
        (180, 500),
        (350, 450),
        (500, 500),
        (650, 400),
        (400, 300),
        (150, 250),
        (300, 200),
        (550, 150),
    ]

    for x, y in platform_positions:
        plat = Platform(x, y)
        platforms.add(plat)
        all_sprites.add(plat)

    last_platform = platform_positions[-1]
    goal = Goal(last_platform[0], last_platform[1])
    all_sprites.add(goal)

    # ---------------- GAME LOOP ----------------
    running = True
    while running:
        clock.tick(FPS)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return "quit"
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    player.jump()
                if event.key == pygame.K_ESCAPE:
                    return "quit"

        player.update(platforms)
        
        if player.rect.top > HEIGHT:  
            code.game_state.player_keys = {k: False for k in code.game_state.player_keys}
            fade_out(screen, duration=0.5)
            return "restart_adventure"  

        if player.rect.colliderect(goal.rect):
            code.game_state.player_keys["platform_key"] = True
            fade_out(screen, duration=0.5)
            return "win"

        # ---------------- DRAW ----------------
        screen.blit(background, (0, 0))  # Draw background first
        all_sprites.draw(screen)         # Draw platforms, goal, player
        if hardcore_heart:
            screen.blit(hardcore_heart, (10, 10))  # Draw hardcore heart icon
        pygame.display.flip()