import pygame
import os
import sys
import code.platformer
import code.laser_labyrinth
import code.room
from code.room import run_room
from code.game_state import player_keys, player_has_pink, pink_pos
import code.game_state

# ------------------- VARIABLES ------------------
WHITE = (255,255,255)
BLACK = (0,0,0)

# -------------------- SETTINGS --------------------
WIDTH, HEIGHT = 1200, 800
FPS = 60
CENTER = (WIDTH // 2, HEIGHT // 2)
SPEED = 7

SPRITE_SELECTION_WIDTH, SPRITE_SELECTION_HEIGHT = 185, 200 
SPRITE_WIDTH, SPRITE_HEIGHT = 60, 75
ZOOM_DURATION = 0.5

# -------------------- FUNCTIONS --------------------
def load_image(path, size=None):
    if os.path.exists(path):
        image = pygame.image.load(path).convert_alpha()
        if size:
            image = pygame.transform.scale(image, size)
        return image
    else:
        print(f"File not found: {path}")
        return None
    
def is_walkable(bg_surface, sprite_rect):
    # Check the pixel at the center of the sprite
    center_x = sprite_rect.centerx
    center_y = sprite_rect.centery

    # Make sure we don't go out of bounds
    if center_x < 0 or center_x >= bg_surface.get_width() or center_y < 0 or center_y >= bg_surface.get_height():
        return False

    pixel_color = bg_surface.get_at((center_x, center_y))  # Returns (R,G,B,A)
    
    # Walkable if pixel is white (255,255,255)
    return pixel_color[:3] == (255, 255, 255)

def zoom_transition(start_surface, end_surface, screen, duration=0.5, zoom_in=True):
    clock = pygame.time.Clock()
    frames = int(duration * FPS)
    
    for i in range(frames):
        t = i / frames  
        scale = 1 + t if zoom_in else 2 - t  

        new_width = int(WIDTH * scale)
        new_height = int(HEIGHT * scale)
        scaled_surface = pygame.transform.smoothscale(start_surface, (new_width, new_height))

        offset_x = (WIDTH - new_width) // 2
        offset_y = (HEIGHT - new_height) // 2

        screen.fill((0,0,0))
        screen.blit(scaled_surface, (offset_x, offset_y))
        pygame.display.flip()
        clock.tick(FPS)

    screen.blit(end_surface, (0,0))
    pygame.display.flip()

def show_dialogue(screen, background_img, text, char_img=None, item_img=None, walk=False, sprite_pos=None, font_size=28, duration=7000, walk_duration=3000, y_offset=None):
    """
    Shows a dialogue with optional character walking and/or item image.
    - font_size: smaller for longer text
    - duration: milliseconds for static dialogues
    - walk_duration: milliseconds for character walking
    - y_offset: vertical start position for text
    """
    clock = pygame.time.Clock()
    dialogue_font = pygame.font.Font(
        '/Users/albertlungu/Documents/GitHub/The-Sleepwalkers/assets/main/PixemonTrialRegular-p7nLK.ttf',
        font_size
    )

    # Word-wrap function
    def wrap_text(text, font, max_width):
        words = text.split(' ')
        lines = []
        current_line = ''
        for word in words:
            test_line = current_line + ' ' + word if current_line else word
            if font.size(test_line)[0] <= max_width:
                current_line = test_line
            else:
                lines.append(current_line)
                current_line = word
        if current_line:
            lines.append(current_line)
        return lines

    lines = wrap_text(text, dialogue_font, WIDTH - 100)

    # Default y_offset if not provided
    if y_offset is None:
        y_offset = HEIGHT - 200

    # Walk animation setup
    if char_img and walk and sprite_pos:
        char_x, char_y = sprite_pos
        target_x = char_x + 300  # distance to move
        total_frames = walk_duration / (1000 / FPS)  # total frames based on duration and FPS
        step = (target_x - char_x) / total_frames  # pixels per frame

    running = True
    start_time = pygame.time.get_ticks()

    while running:
        clock.tick(FPS)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()

        screen.blit(background_img, (0, 0))

        # Draw character walking
        if char_img and walk and sprite_pos:
            scaled_char = pygame.transform.smoothscale(char_img, (SPRITE_WIDTH, SPRITE_HEIGHT))
            screen.blit(scaled_char, (char_x, char_y))
            char_x += step
            if char_x >= target_x:
                char_x = target_x
                running = False

        # Draw item image (scaled nicely)
        if item_img:
            item_scaled = pygame.transform.smoothscale(item_img, (100, 100))
            screen.blit(item_scaled, (WIDTH - item_scaled.get_width() - 50, HEIGHT - item_scaled.get_height() - 50))

        # Draw dialogue text
        for i, line in enumerate(lines):
            text_surf = dialogue_font.render(line, True, (255, 255, 255))
            screen.blit(text_surf, (50, y_offset + i * (font_size + 5)))

        pygame.display.flip()

        # Static dialogues last longer
        if not walk and pygame.time.get_ticks() - start_time >= duration:
            running = False
        clock.tick(FPS)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()

        screen.blit(background_img, (0, 0))

        # Draw character walking
        if char_img and walk and sprite_pos:
            scaled_char = pygame.transform.smoothscale(char_img, (SPRITE_WIDTH, SPRITE_HEIGHT))
            screen.blit(scaled_char, (char_x, char_y))
            char_x += step
            if char_x >= target_x:
                char_x = target_x
                running = False

        # Draw item image (scaled nicely)
        if item_img:
            item_scaled = pygame.transform.smoothscale(item_img, (100, 100))
            screen.blit(item_scaled, (WIDTH - item_scaled.get_width() - 50, HEIGHT - item_scaled.get_height() - 50))

        # Draw dialogue text
        for i, line in enumerate(lines):
            text_surf = dialogue_font.render(line, True, (255, 255, 255))
            screen.blit(text_surf, (50, HEIGHT - 200 + i * (font_size + 5)))

        pygame.display.flip()

        # Static dialogues last longer
        if not walk and pygame.time.get_ticks() - start_time >= duration:
            running = False
    
def draw_title_rect(x, y, l, w, font, mouse_pos):
    rect = pygame.Rect(x, y, l, w)
    hover_scale = 1.1 if rect.collidepoint(mouse_pos) else 1.0
    scaled_width = int(l * hover_scale)
    scaled_height = int(w * hover_scale)

    offset_x = rect.centerx - scaled_width // 2
    offset_y = rect.centery - scaled_height // 2

    button_surface = pygame.Surface((scaled_width, scaled_height), pygame.SRCALPHA)
    fill_color = (220, 220, 220, 220) if rect.collidepoint(mouse_pos) else (200, 200, 200, 180)
    border_color = WHITE

    pygame.draw.rect(button_surface, fill_color, button_surface.get_rect(), border_radius=15)
    pygame.draw.rect(button_surface, border_color, button_surface.get_rect(), width=3, border_radius=15)

    text_surface = font.render("Play", True, BLACK)
    text_rect = text_surface.get_rect(center=button_surface.get_rect().center)
    button_surface.blit(text_surface, text_rect)

    screen.blit(button_surface, (offset_x, offset_y))

    return pygame.Rect(offset_x, offset_y, scaled_width, scaled_height)

def draw_selection_screen(boxes, mouse_pos):
    screen.fill((50, 50, 150))  
    for i, rect in enumerate(boxes):
        hover_scale = 1.1 if rect.collidepoint(mouse_pos) else 1.0
        scaled_width = int(rect.width * hover_scale)
        scaled_height = int(rect.height * hover_scale)

        offset_x = rect.centerx - scaled_width // 2
        offset_y = rect.centery - scaled_height // 2

        box_surface = pygame.Surface((scaled_width, scaled_height), pygame.SRCALPHA)
        fill_color = (220, 220, 220, 220) if rect.collidepoint(mouse_pos) else (200, 200, 200, 180)
        border_color = WHITE

        pygame.draw.rect(box_surface, fill_color, box_surface.get_rect(), border_radius=15)
        pygame.draw.rect(box_surface, border_color, box_surface.get_rect(), width=3, border_radius=15)
        screen.blit(box_surface, (offset_x, offset_y))

        if i == 0:
            sprite_rect = sprite_1_selection.get_rect(center=(rect.centerx, rect.centery))
            sprite_rect.topleft = (sprite_rect.x, sprite_rect.y)
            screen.blit(sprite_1_selection, sprite_rect.topleft)
        elif i == 1:
            sprite_rect = sprite_2_selection.get_rect(center=(rect.centerx, rect.centery))
            sprite_rect.topleft = (sprite_rect.x, sprite_rect.y)
            screen.blit(sprite_2_selection, sprite_rect.topleft)
        elif i == 2:
            sprite_rect = sprite_3_selection.get_rect(center=(rect.centerx, rect.centery))
            sprite_rect.topleft = (sprite_rect.x, sprite_rect.y)
            screen.blit(sprite_3_selection, sprite_rect.topleft)
        elif i == 3:
            sprite_rect = sprite_4_selection.get_rect(center=(rect.centerx, rect.centery))
            sprite_rect.topleft = (sprite_rect.x, sprite_rect.y)
            screen.blit(sprite_4_selection, sprite_rect.topleft)

def get_selection_surface(boxes):
    temp_surface = pygame.Surface((WIDTH, HEIGHT))
    temp_surface.fill((50,50,150))  
    for rect in boxes:
        box_surface = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
        pygame.draw.rect(box_surface, (200,200,200,180), box_surface.get_rect(), border_radius=15)
        pygame.draw.rect(box_surface, WHITE, box_surface.get_rect(), width=3, border_radius=15)
        temp_surface.blit(box_surface, rect.topleft)
    return temp_surface

# -------------------- INITIALIZATION --------------------
pygame.init()
font = pygame.font.Font(
    'assets/main/PixemonTrialRegular-p7nLK.ttf', 
    38
)
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Camera with Edges")
clock = pygame.time.Clock()

# Load images
titleScreen = load_image("assets/main/title_page.png", (WIDTH, HEIGHT))
titleScreenPoster = load_image("assets/main/title_page_poster.png" , (800, 530))

hardcore_heart = load_image("assets/main/hardcore_heart.png", (50, 50))

foreground = load_image("assets/main/map_foreground.png", (WIDTH*2, HEIGHT*2))
background = load_image("assets/main/map_background.png", (WIDTH*2, HEIGHT*2))
path_image = load_image("assets/main/path_background.png", (WIDTH*2, HEIGHT*2))

sprite_1 = load_image("assets/main/sprite_1.png", (SPRITE_WIDTH - 10, SPRITE_HEIGHT))
sprite_1_selection = load_image("assets/main/sprite_1.png", (SPRITE_SELECTION_WIDTH, SPRITE_SELECTION_HEIGHT))

sprite_2 = load_image("assets/main/sprite_2.png", (SPRITE_WIDTH - 10, SPRITE_HEIGHT))
sprite_2_selection = load_image("assets/main/sprite_2.png", (SPRITE_SELECTION_WIDTH, SPRITE_SELECTION_HEIGHT))

sprite_3 = load_image("assets/main/sprite_3.png", (SPRITE_WIDTH - 10, SPRITE_HEIGHT))
sprite_3_selection = load_image("assets/main/sprite_3.png", (SPRITE_SELECTION_WIDTH, SPRITE_SELECTION_HEIGHT))

sprite_4 = load_image("assets/main/sprite_4.png", (SPRITE_WIDTH, SPRITE_HEIGHT))
sprite_4_selection = load_image("assets/main/sprite_4.png", (SPRITE_SELECTION_WIDTH - 65, SPRITE_SELECTION_HEIGHT - 65))


# Sprite/world
sprite_pos = [100, 100]
selected_sprite = None 
bg_offset = [0, 0]

# -------------------- MAIN LOOP --------------------
def main():
    running = True
    global selected_sprite, sprite_pos, player_has_pink, pink_pos

    current_screen = 'title'

    box_width, box_height = 200, 300
    padding = 50
    start_x = (WIDTH - (2 * box_width + padding)) // 2
    start_y = (HEIGHT - (2 * box_height + padding)) // 2

    boxes = [
        pygame.Rect(start_x, start_y, box_width, box_height),
        pygame.Rect(start_x + box_width + padding, start_y, box_width, box_height),
        pygame.Rect(start_x, start_y + box_height + padding, box_width, box_height),
        pygame.Rect(start_x + box_width + padding, start_y + box_height + padding, box_width, box_height)
    ]

    while running:

        clock.tick(FPS)
        mouse_pos = pygame.mouse.get_pos()
        mouse_pressed = pygame.mouse.get_pressed()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        
        if current_screen == "title":
            screen.blit(titleScreen, (0,0))
            screen.blit(titleScreenPoster, (WIDTH//2 - 370, HEIGHT//2 - 200))

            button_rect = pygame.Rect(WIDTH//2 - 70, HEIGHT//2 + 150, 140, 50)
            pygame.draw.rect(screen, (200,200,200), button_rect)
            text_surf = font.render("Play", True, BLACK)
            screen.blit(text_surf, text_surf.get_rect(center=button_rect.center))

        if mouse_pressed[0] and button_rect.collidepoint(mouse_pos):
            current_screen = "selection"
        
        elif current_screen == "selection":
            draw_selection_screen(boxes, mouse_pos)
            if mouse_pressed[0]:
                for idx, rect in enumerate(boxes):
                    if rect.collidepoint(mouse_pos):
                        if idx == 0: selected_sprite = sprite_1
                        elif idx == 1: selected_sprite = sprite_2
                        elif idx == 2: selected_sprite = sprite_3
                        elif idx == 3: selected_sprite = sprite_4
                        if selected_sprite:
                            if selected_sprite:
                                sprite_pos = [background.get_width()//2 - 100, background.get_height()//2 + 220]

                                # # Zoom out from selection
                                # selection_surface = get_selection_surface(boxes)
                                # zoom_transition(selection_surface, selection_surface, screen, duration=ZOOM_DURATION, zoom_in=True)
                                # zoom_transition(background, background, screen, duration=ZOOM_DURATION, zoom_in=False)

                                # dialogue_1_img = load_image("assets/dialogue/dialogue_1.png", (WIDTH, HEIGHT))
                                # show_dialogue(screen, dialogue_1_img,
                                #             "Once upon a time, there was a warrior named Kashyap who was an avid explorer in his region!",
                                #             char_img=selected_sprite, walk=True, sprite_pos=[100, HEIGHT - 400])

                                # dialogue_2_img = load_image("assets/dialogue/dialogue_2.png", (WIDTH, HEIGHT))
                                # princess_img = load_image("assets/room/princess.png", (200, 200))
                                # key_img = load_image("assets/main/key.png", (50, 50))
                                # show_dialogue(screen, dialogue_2_img,
                                #             'During his adventure of the "Dream of Days", Kashyap was notified of a princess trapped in the deep dark dungeons! The only way to rescue her is to collect the hidden keys of reality, stored in unknown locations across the map!',
                                #             char_img=selected_sprite, item_img=key_img, walk=True, sprite_pos=[100, HEIGHT - 400])
                                # screen.blit(princess_img, (WIDTH//2, HEIGHT//2 - 100))

                                # dialogue_3_img = load_image("assets/dialogue/dialogue_3.png", (WIDTH, HEIGHT))
                                # show_dialogue(screen, dialogue_3_img,
                                #             "YOU (being Kashyap) is incredibly up for the task, and decide to rise up to the challenge, and save the princess from the forbidden dark! However, you MUST BE CAREFUL as any deaths will forever kill you in this fantasy world, with no mercy for respawns!",
                                #             char_img=selected_sprite, walk=False)

                                # dialogue_4_img = load_image("assets/dialogue/dialogue_4.png", (WIDTH, HEIGHT))
                                # fairy_img = load_image("assets/room/fairy.png", (150, 150))
                                # show_dialogue(screen, dialogue_4_img,
                                #     "Good luck brave warrior! I wish you all the best in your adventure!",
                                #     char_img=selected_sprite, item_img=fairy_img, walk=False,
                                #     y_offset=HEIGHT - 120) 

                                # # Finally, switch to the game screen
                                current_screen = "game"
        
        elif current_screen == "game" and selected_sprite:

            # ---------------- Movement ----------------
            keys = pygame.key.get_pressed()
            dx, dy = 0, 0
            if keys[pygame.K_LEFT]: dx = -SPEED
            if keys[pygame.K_RIGHT]: dx = SPEED
            if keys[pygame.K_UP]: dy = -SPEED
            if keys[pygame.K_DOWN]: dy = SPEED

            # Tentative new position
            new_x = sprite_pos[0] + dx
            new_y = sprite_pos[1] + dy

            # Player rectangle at new position
            new_rect = pygame.Rect(new_x, new_y, selected_sprite.get_width(), selected_sprite.get_height())

            # Check walkable pixels on your path mask (white = walkable)
            walkable = True
            for corner in [(new_rect.left, new_rect.top),
                        (new_rect.right, new_rect.top),
                        (new_rect.left, new_rect.bottom),
                        (new_rect.right, new_rect.bottom)]:
                # Make sure inside image bounds
                px = max(0, min(corner[0], path_image.get_width() - 1))
                py = max(0, min(corner[1], path_image.get_height() - 1))
                if path_image.get_at((px, py))[:3] != (255, 255, 255):  # Not white → blocked
                    walkable = False
                    break

            # Only move if walkable
            if walkable:
                sprite_pos[0] = new_x
                sprite_pos[1] = new_y

            player_rect = pygame.Rect(sprite_pos[0], sprite_pos[1],
                                    selected_sprite.get_width(), selected_sprite.get_height())

            # ---------------- Entrances ----------------

            laser_entrance_rect = pygame.Rect(1250, 480, 130, 120)
            room_entrance_rect = pygame.Rect(background.get_width()//2 - 175, background.get_height()//2 - 20, 150, 200)
            entrance_rect = pygame.Rect(1570, 800, 100, 130)  


            if player_rect.colliderect(entrance_rect):
                result = code.platformer.run_platformer(screen, selected_sprite)
                if result == "quit": 
                    running = False
                    sprite_pos = [1570, 700] 
                elif result == "restart_adventure":
                    sprite_pos[:] = [background.get_width()//2 - 100, background.get_height()//2 + 220]
                    for key in player_keys:
                        player_keys[key] = False
                sprite_pos = [1570, 700]
                
            
           
            if player_rect.colliderect(laser_entrance_rect):
                if player_keys["platform_key"]:
                    entrance_spawn = [background.get_width()//2, background.get_height()//2]
                    result = code.laser_labyrinth.run_laser_labyrinth(screen, selected_sprite)
                    if result == "quit": 
                        running = False
                        sprite_pos = entrance_spawn  # return to entrance
                    elif result == "restart_adventure":
                        sprite_pos[:] = [background.get_width()//2 - 100, background.get_height()//2 + 220]
                        for key in player_keys:
                            player_keys[key] = False
                    sprite_pos = [1570, 700]
                    
                else:
                    font_small = pygame.font.Font(None, 36)
                    msg = font_small.render("You need the Platform Key!", True, (255,0,0))
                    screen.blit(msg, (WIDTH//2 - msg.get_width()//2, HEIGHT//2 - 50))
            
            if player_rect.colliderect(room_entrance_rect):
                if player_keys.get("lab_key", False):
                    entrance_spawn = [background.get_width()//2 - 200, background.get_height()//2 - 40]
                    result = code.room.run_room(screen, selected_sprite)

                    if result == "quit": 
                        running = False
                        sprite_pos = [1570, 700]
                    else:
                        # Player successfully rescued the princess
                        win_img = load_image("assets/main/win.png", (WIDTH, HEIGHT))
                        screen.blit(win_img, (0, 0))
                        pygame.display.flip()

                        # Wait so player can see the win screen
                        waiting = True
                        while waiting:
                            for event in pygame.event.get():
                                if event.type == pygame.QUIT:
                                    waiting = False
                                    running = False
                                elif event.type == pygame.KEYDOWN or event.type == pygame.MOUSEBUTTONDOWN:
                                    waiting = False  # Close win screen when any key or mouse is pressed
                        # Exit game after win
                        running = False

                else:
                    font_small = pygame.font.Font(None, 36)
                    msg = font_small.render("You need the Lab Key to enter!", True, (255,0,0))
                    screen.blit(msg, (WIDTH//2 - msg.get_width()//2, HEIGHT//2 - 50))

            # ---------------- Camera ----------------
            bg_offset[0] = -(sprite_pos[0] - WIDTH//2)
            bg_offset[1] = -(sprite_pos[1] - HEIGHT//2)
            bg_offset[0] = min(0, max(bg_offset[0], WIDTH - background.get_width()))
            bg_offset[1] = min(0, max(bg_offset[1], HEIGHT - background.get_height()))

            # ---------------- Drawing ----------------
            screen.blit(background, bg_offset)
            screen.blit(selected_sprite, (sprite_pos[0] + bg_offset[0], sprite_pos[1] + bg_offset[1]))
            screen.blit(foreground, bg_offset)

            if hardcore_heart:
                screen.blit(hardcore_heart, (10, 10))

            # pygame.draw.rect(screen, (255, 0, 0), (entrance_rect.x + bg_offset[0], entrance_rect.y + bg_offset[1], entrance_rect.width, entrance_rect.height))
            # pygame.draw.rect(screen, (0, 0, 255), (laser_entrance_rect.x + bg_offset[0], laser_entrance_rect.y + bg_offset[1], laser_entrance_rect.width, laser_entrance_rect.height))
            # pygame.draw.rect(screen, (255, 165, 0), (room_entrance_rect.x + bg_offset[0], room_entrance_rect.y + bg_offset[1], room_entrance_rect.width, room_entrance_rect.height))

            # ---------------- Pink Trail ----------------
            if code.game_state.player_has_pink:
                code.game_state.pink_pos[0] = player_rect.x + 10
                code.game_state.pink_pos[1] = player_rect.y + 10
                screen.blit(load_image("assets/room/princess.png", (200, 200)), (code.game_state.pink_pos[0] + bg_offset[0], code.game_state.pink_pos[1] + bg_offset[1]))

        pygame.display.flip()

    pygame.quit()

if __name__ == "__main__":
    main()