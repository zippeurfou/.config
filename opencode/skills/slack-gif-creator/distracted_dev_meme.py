from PIL import Image, ImageDraw, ImageFont
from core.gif_builder import GIFBuilder
from core.frame_composer import draw_emoji_enhanced
from core.easing import interpolate
from core.typography import draw_text_with_outline, TYPOGRAPHY_SCALE
import math

# Create GIF for Slack message (480x480)
builder = GIFBuilder(width=480, height=480, fps=15)

# Positions
doc_pos = (100, 240)      # Documentation on left
dev_pos = (240, 240)       # Developer in center
ai_pos = (380, 240)        # AI tool on right

# Animation phases
total_frames = 60

for i in range(total_frames):
    # Create background
    frame = Image.new('RGB', (480, 480), (240, 248, 255))
    
    # Phase 1: Setup (frames 0-15) - everyone normal
    # Phase 2: Turn (frames 15-30) - developer turns head
    # Phase 3: React (frames 30-45) - documentation reacts
    # Phase 4: Hold (frames 45-60) - hold the scene
    
    # Draw documentation (left)
    if i < 30:
        # Normal
        draw_emoji_enhanced(frame, '📚', position=(doc_pos[0]-35, doc_pos[1]-35), size=70, shadow=False)
    else:
        # Sad/disappointed after frame 30
        draw_emoji_enhanced(frame, '📚', position=(doc_pos[0]-35, doc_pos[1]-35), size=70, shadow=False)
        # Add sad face next to it
        draw_emoji_enhanced(frame, '😢', position=(doc_pos[0]-20, doc_pos[1]-60), size=30, shadow=False)
    
    # Draw developer (center) - head turns
    if i < 15:
        # Looking at documentation (normal)
        draw_emoji_enhanced(frame, '🧑‍💻', position=(dev_pos[0]-40, dev_pos[1]-40), size=80, shadow=False)
    elif i < 30:
        # Turning head toward AI
        t = (i - 15) / 15
        # Simulate head turn with rotation effect - just shift position slightly
        offset_x = int(interpolate(0, 20, t, 'ease_in_out'))
        draw_emoji_enhanced(frame, '🧑‍💻', position=(dev_pos[0]-40+offset_x, dev_pos[1]-40), size=80, shadow=False)
        # Add eyes looking right
        eye_offset = int(interpolate(0, 15, t, 'ease_in_out'))
        draw_emoji_enhanced(frame, '👀', position=(dev_pos[0]-10+eye_offset, dev_pos[1]-50), size=20, shadow=False)
    else:
        # Fully turned, looking at AI
        draw_emoji_enhanced(frame, '🧑‍💻', position=(dev_pos[0]-40+20, dev_pos[1]-40), size=80, shadow=False)
        draw_emoji_enhanced(frame, '👀', position=(dev_pos[0]+5, dev_pos[1]-50), size=20, shadow=False)
    
    # Draw AI tool (right) - gets attention
    if i < 15:
        # Normal
        draw_emoji_enhanced(frame, '🤖', position=(ai_pos[0]-35, ai_pos[1]-35), size=70, shadow=False)
    else:
        # Glowing/pulsing to show it's attractive
        pulse_scale = 1.0 + math.sin((i - 15) * 0.4) * 0.1
        size = int(70 * pulse_scale)
        offset = int((70 - size) / 2)
        draw_emoji_enhanced(frame, '🤖', position=(ai_pos[0]-35+offset, ai_pos[1]-35+offset), size=size, shadow=False)
        # Add sparkles
        if i % 4 < 2:
            draw_emoji_enhanced(frame, '✨', position=(ai_pos[0]-55, ai_pos[1]-60), size=25, shadow=False)
            draw_emoji_enhanced(frame, '✨', position=(ai_pos[0]+10, ai_pos[1]-60), size=25, shadow=False)
    
    # Add caption at bottom
    if i >= 20:
        draw_text_with_outline(
            frame, 
            "When AI drops a new feature",
            position=(240, 400),
            font_size=32,
            text_color=(50, 50, 50),
            outline_color=(255, 255, 255),
            outline_width=2,
            centered=True
        )
    
    builder.add_frame(frame)

# Save the GIF
info = builder.save('distracted_dev.gif', num_colors=128, optimize_for_emoji=False)
print(f"✅ Created distracted_dev.gif")
print(f"   Size: {info['size_mb']:.2f}MB ({info['size_kb']:.1f}KB)")
print(f"   Frames: {info['frame_count']}")
print(f"   Duration: {info['duration_seconds']:.1f}s")
