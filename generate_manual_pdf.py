import os
import sys
import pymupdf
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

# ----------------------------------------------------------------------
# 1. NumberedCanvas for Two-Pass Header and Footer
# ----------------------------------------------------------------------
class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_decorations(self, page_count):
        self.saveState()
        w, h = letter

        navy = colors.HexColor('#1E3A8A')
        slate = colors.HexColor('#64748B')
        rule_color = colors.HexColor('#CBD5E1')

        # Running Header on Pages 2..N
        if self._pageNumber > 1:
            self.setFont('Helvetica-Bold', 7.5)
            self.setFillColor(navy)
            self.drawString(36, h - 22, "MSPHYSICS COMPLETE TOOLS & OPERATIONS GUIDE")
            self.setFont('Helvetica', 7.5)
            self.setFillColor(slate)
            self.drawRightString(w - 36, h - 22, "Trimble SketchUp 2024–2026 Physics Simulation Suite")
            
            self.setStrokeColor(rule_color)
            self.setLineWidth(0.6)
            self.line(36, h - 25, w - 36, h - 25)

        # Running Footer on all pages
        self.setStrokeColor(rule_color)
        self.setLineWidth(0.6)
        self.line(36, 24, w - 36, 24)

        self.setFont('Helvetica', 7.0)
        self.setFillColor(slate)
        self.drawString(36, 14, "MSPhysics 1.3+ User Manual | Newton Dynamics 3.14 Engine | Ruby 3.2 UCRT | AMS Library 3.8.0")

        self.setFont('Helvetica-Bold', 7.0)
        self.setFillColor(navy)
        self.drawRightString(w - 36, 14, f"Page {self._pageNumber} of {page_count}")

        self.restoreState()


# Colors
PRIMARY = colors.HexColor('#1E3A8A')      # Deep Navy
SECONDARY = colors.HexColor('#0284C7')    # Vibrant Blue
ACCENT = colors.HexColor('#D97706')       # Warm Amber
DARK_TEXT = colors.HexColor('#0F172A')    # Slate 900
BODY_TEXT = colors.HexColor('#334155')    # Slate 700
LIGHT_BG = colors.HexColor('#F8FAFC')     # Slate 50
ALT_ROW = colors.HexColor('#F1F5F9')      # Slate 100
BORDER_COL = colors.HexColor('#CBD5E1')   # Slate 300
GREEN_COL = colors.HexColor('#15803D')    # Emerald 700
PURPLE_COL = colors.HexColor('#7C3AED')   # Purple 700
BLUE_BG = colors.HexColor('#EFF6FF')      # Soft Blue
AMBER_BG = colors.HexColor('#FEF3C7')     # Soft Amber

# Typography Styles
styles = getSampleStyleSheet()

title_style = ParagraphStyle('DocTitle', fontName='Helvetica-Bold', fontSize=18, leading=21, textColor=PRIMARY)
subtitle_style = ParagraphStyle('DocSubTitle', fontName='Helvetica-Bold', fontSize=9, leading=11.5, textColor=SECONDARY)
banner_title = ParagraphStyle('BannerTitle', fontName='Helvetica-Bold', fontSize=8.5, leading=10.5, textColor=colors.white)
banner_tag = ParagraphStyle('BannerTag', fontName='Helvetica-Bold', fontSize=7.2, leading=9.0, textColor=colors.HexColor('#BAE6FD'), alignment=2)
h2_style = ParagraphStyle('SectionH2', fontName='Helvetica-Bold', fontSize=8.0, leading=10.0, textColor=PRIMARY, keepWithNext=True)
h3_style = ParagraphStyle('SectionH3', fontName='Helvetica-Bold', fontSize=7.2, leading=9.0, textColor=DARK_TEXT, keepWithNext=True)
body_style = ParagraphStyle('CustomBody', fontName='Helvetica', fontSize=6.6, leading=8.2, textColor=BODY_TEXT)
body_bold = ParagraphStyle('CustomBodyBold', fontName='Helvetica-Bold', fontSize=6.6, leading=8.2, textColor=DARK_TEXT)
bullet_style = ParagraphStyle('CustomBullet', fontName='Helvetica', fontSize=6.4, leading=7.8, textColor=BODY_TEXT, leftIndent=5)
th_style = ParagraphStyle('CustomTH', fontName='Helvetica-Bold', fontSize=6.6, leading=8.0, textColor=colors.white, alignment=1)
td_style = ParagraphStyle('CustomTD', fontName='Helvetica', fontSize=6.3, leading=7.6, textColor=DARK_TEXT)
td_bold = ParagraphStyle('CustomTDBold', fontName='Helvetica-Bold', fontSize=6.3, leading=7.6, textColor=DARK_TEXT)
td_code = ParagraphStyle('CustomTDCode', fontName='Courier-Bold', fontSize=5.9, leading=7.0, textColor=PRIMARY)
callout_text = ParagraphStyle('CalloutText', fontName='Helvetica', fontSize=6.4, leading=7.8, textColor=DARK_TEXT)
callout_bold = ParagraphStyle('CalloutBold', fontName='Helvetica-Bold', fontSize=6.4, leading=7.8, textColor=PRIMARY)

def make_banner(title_text, tag_text="CORE MODULE"):
    tbl = Table([
        [Paragraph(title_text, banner_title), Paragraph(tag_text, banner_tag)]
    ], colWidths=[380, 160])
    tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), PRIMARY),
        ('ALIGN', (0,0), (0,0), 'LEFT'),
        ('ALIGN', (1,0), (1,0), 'RIGHT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 2.0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2.0),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    return tbl

def build_pdf(filename="MSPhysics_Tools_and_Operations_Guide.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=36,
        rightMargin=36,
        topMargin=28,
        bottomMargin=28
    )

    story = []

    # =========================================================================
    # PAGE 1: TITLE, EXECUTIVE OVERVIEW, ARCHITECTURE & QUICK START
    # =========================================================================
    logo_path = 'MSPhysics/images/msphysics-logo.png'
    logo_img = Image(logo_path, width=175, height=38.3)
    
    meta_data = [
        [Paragraph("<b>Version:</b> 1.3.0+ (2026 Edition)", td_style), Paragraph("<b>Ruby ABI:</b> 3.2.2 UCRT (x64-ucrt-ruby320)", td_style)],
        [Paragraph("<b>Target Host:</b> SketchUp 2024–2026 (Win64/Mac64)", td_style), Paragraph("<b>Physics Core:</b> Newton Dynamics 3.14", td_style)],
        [Paragraph("<b>Dependency:</b> AMS Library 3.8.0+", td_style), Paragraph("<b>Status:</b> Production Ready & Hardened", td_style)]
    ]
    meta_table = Table(meta_data, colWidths=[175, 175])
    meta_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 1.8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.8),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
    ]))

    header_table = Table([[logo_img, meta_table]], colWidths=[185, 355])
    header_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ALIGN', (0,0), (0,0), 'LEFT'),
        ('ALIGN', (1,0), (1,0), 'RIGHT'),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 2))

    story.append(Paragraph("MSPhysics: Complete Tools & Operations Guide", title_style))
    story.append(Paragraph("Comprehensive User & Technical Reference Manual for Real-Time Physics in Trimble SketchUp", subtitle_style))
    story.append(Spacer(1, 2))
    story.append(HRFlowable(width="100%", thickness=1, color=PRIMARY, spaceBefore=1, spaceAfter=2))

    arch_html = (
        "<b>Executive Overview:</b> MSPhysics is an advanced real-time rigid-body and kinematic simulation suite embedded directly within "
        "Trimble SketchUp. Built atop the high-performance <b>Newton Dynamics 3.14</b> C++ physics engine and coupled with <b>AMS Library 3.8.0</b>, "
        "it enables architects, mechanical designers, animators, and engineers to simulate physical mechanisms, evaluate structural dynamics, "
        "model multi-body kinematics, drive vehicles, and export photorealistic keyframed physics animations. "
        "The suite is organized into distinct specialized toolsets covering live execution, joint articulation, transmission gearing, timeline replay, "
        "deep property inspection, and build-time cross-compilation."
    )
    arch_tbl = Table([[Paragraph(arch_html, callout_text)]], colWidths=[540])
    arch_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), BLUE_BG),
        ('BOX', (0,0), (-1,-1), 0.8, SECONDARY),
        ('TOPPADDING', (0,0), (-1,-1), 2.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2.5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(arch_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Master Toolsets Taxonomy", h2_style))
    taxonomy_data = [
        [Paragraph("Toolset Family", th_style), Paragraph("Count", th_style), Paragraph("Core Capabilities & Functional Focus", th_style), Paragraph("Primary Access Point", th_style)],
        [Paragraph("<b>Simulation Controls</b>", td_bold), Paragraph("5 tools", td_style), Paragraph("Full model play, selective execution (Play 2), pause, reset, freeze-in-place stop, and UI inspector toggle.", td_style), Paragraph("Toolbar: <i>MSPhysics</i>", td_style)],
        [Paragraph("<b>Joint Connection & Scaling</b>", td_bold), Paragraph("3 tools", td_style), Paragraph("Interactive joint-to-body binding tool with modifier keys (Ctrl/Shift), joint scaling gizmo, and gear pairing.", td_style), Paragraph("Toolbar: <i>MSPhysics Joints</i>", td_style)],
        [Paragraph("<b>Joint Creation & Actuators</b>", td_bold), Paragraph("14 joints", td_style), Paragraph("Parametric kinematic constraints: Hinge, Motor, Servo, Slider, Piston, Spring, Corkscrew, Ball/Socket, Universal, Fixed, Plane, Curvy Slider, Curvy Piston, UpVector.", td_style), Paragraph("Toolbar: <i>MSPhysics Joints</i>", td_style)],
        [Paragraph("<b>Replay & Keyframing</b>", td_bold), Paragraph("10 tools", td_style), Paragraph("Deterministic frame recording, camera tracking, bidirectional playback, speed scaling, scene page generation.", td_style), Paragraph("Toolbar: <i>MSPhysics Replay</i>", td_style)],
        [Paragraph("<b>UI Dialog & Scripting</b>", td_bold), Paragraph("5 tabs", td_style), Paragraph("World gravity/solver settings, 10 collision mesh types, material densities, thrusters/emitters, Ruby IDE, 3D audio.", td_style), Paragraph("Dialog: <i>Toggle UI</i>", td_style)],
        [Paragraph("<b>Developer & Build Tools</b>", td_bold), Paragraph("3 suites", td_style), Paragraph("Zig C++ cross-compiler for Ruby 3.2 UCRT, upstream C++ patcher, and headless WASM test harness.", td_style), Paragraph("Scripts: <i>tools/</i> & <i>harness/</i>", td_style)]
    ]
    tax_table = Table(taxonomy_data, colWidths=[105, 45, 275, 115])
    tax_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, ALT_ROW]),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ALIGN', (1,0), (1,-1), 'CENTER'),
    ]))
    story.append(tax_table)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Essential 4-Step Physics Workflow", h2_style))
    step_data = [
        [
            Paragraph("<b>STEP 1: Model & Group</b>", td_bold),
            Paragraph("<b>STEP 2: Place Joints</b>", td_bold),
            Paragraph("<b>STEP 3: Connect & Bind</b>", td_bold),
            Paragraph("<b>STEP 4: Simulate & Control</b>", td_bold)
        ],
        [
            Paragraph("Encapsulate solid geometry into Groups or Component Instances. Assign collision shape (e.g. Box, Convex Hull) and material/mass in UI.", td_style),
            Paragraph("Select a joint tool (e.g. Hinge). Click Point 1 for anchor origin; click Point 2 to align primary constraint axis (Blue Z-vector).", td_style),
            Paragraph("Activate Joint Connection Tool. Click the Body, hold <b>CTRL</b> and click the Joint. Joint turns GREEN confirming active binding.", td_style),
            Paragraph("Click <b>Toggle Play</b>. Interact with dynamic bodies using mouse spring drag, control sliders, or keyboard controllers (WSADQE).", td_style)
        ]
    ]
    step_tbl = Table(step_data, colWidths=[135, 135, 135, 135])
    step_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), ALT_ROW),
        ('BACKGROUND', (0,1), (-1,1), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 1.8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.8),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(step_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Core Physical Classifications & Solver Architecture", h2_style))
    concepts_data = [
        [
            Paragraph("<b>Dynamic Rigid Bodies:</b> Top-level groups possessing mass and inertia, fully governed by forces, gravity, and Newton collision laws.", bullet_style),
            Paragraph("<b>Static Colliders:</b> Top-level geometry marked as 'Static' or untouched in selective simulation; acts as immovable world terrain.", bullet_style)
        ],
        [
            Paragraph("<b>Kinematic / Frozen Bodies:</b> Bodies controlled explicitly by scripts or joints; unaffected by external forces until awakened.", bullet_style),
            Paragraph("<b>Substepping & Continuous Collision (CCD):</b> Solver advances at 60–240 Hz with CCD to prevent fast objects from tunneling thin walls.", bullet_style)
        ]
    ]
    concepts_tbl = Table(concepts_data, colWidths=[270, 270])
    concepts_tbl.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('BACKGROUND', (0,0), (-1,-1), colors.white),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(concepts_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Physics Units, Coordinate Systems & Numerical Modeling Standards", h2_style))
    units_data = [
        [
            Paragraph("Physical Quantity", th_style),
            Paragraph("Standard Unit", th_style),
            Paragraph("Default Constant / Value", th_style),
            Paragraph("Engineering Modeling Best Practice", th_style)
        ],
        [
            Paragraph("<b>Length & Distance</b>", td_bold),
            Paragraph("Meters (m) or Inches (in)", td_style),
            Paragraph("SketchUp internal unit (inches converted to m)", td_style),
            Paragraph("Optimal rigid-body scale is 0.1m to 50m. Scale up tiny millimeter parts.", td_style)
        ],
        [
            Paragraph("<b>Mass & Density</b>", td_bold),
            Paragraph("Kilograms (kg), g/cm³", td_style),
            Paragraph("Default material density: 1.0 g/cm³ (Water)", td_style),
            Paragraph("Avoid mass ratios > 100:1 between directly connected joints to prevent jitter.", td_style)
        ],
        [
            Paragraph("<b>Force & Torque</b>", td_bold),
            Paragraph("Newtons (N), N·m", td_style),
            Paragraph("Thrusters, springs, joint limits", td_style),
            Paragraph("Dynamic controllers evaluate in Newtons: F = m·a.", td_style)
        ],
        [
            Paragraph("<b>Coordinate Frame</b>", td_bold),
            Paragraph("Right-handed Z-Up", td_style),
            Paragraph("Red = +X, Green = +Y, Blue = +Z", td_style),
            Paragraph("Global Gravity points along world -Z vector by default ([0, 0, -9.8] m/s²).", td_style)
        ]
    ]
    units_tbl = Table(units_data, colWidths=[95, 105, 150, 190])
    units_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, LIGHT_BG]),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(units_tbl)

    story.append(PageBreak())

    # =========================================================================
    # PAGE 2: SIMULATION TOOLBAR & INTERACTIVE IN-SIMULATION TOOLS
    # =========================================================================
    story.append(make_banner("SECTION 1: SIMULATION TOOLBAR & INTERACTIVE CONTROLS", "CORE EXECUTION"))
    story.append(Spacer(1, 2))
    
    sim_intro = (
        "The <b>MSPhysics Simulation Toolbar</b> is the primary command hub for running, testing, pausing, and freezing dynamic physical simulations. "
        "Unlike standard animations, MSPhysics executes a true non-linear numerical differential solver in real time. "
        "Below is the complete reference for every toolbar command, live interactive viewport controls, and solver execution mechanics."
    )
    story.append(Paragraph(sim_intro, body_style))
    story.append(Spacer(1, 2))

    sim_tools_data = [
        [Paragraph("Tool & Icon", th_style), Paragraph("Command / State", th_style), Paragraph("Primary Physical Function", th_style), Paragraph("Step-by-Step Operational Guide", th_style), Paragraph("Shortcut / Prompt", th_style)],
        [
            Table([[Image('MSPhysics/images/icons/ui.png', width=16, height=16), Paragraph("<b>Toggle UI</b>", td_bold)]], colWidths=[20, 70]),
            Paragraph("Modal / Modeless<br/>State: Checked / Unchecked", td_style),
            Paragraph("Opens or dismisses the floating MSPhysics Inspector Dialog containing Simulation, Body, Joint, Script, and Sound settings.", td_style),
            Paragraph("1. Click button to open inspector.<br/>2. Select any body/joint in SketchUp.<br/>3. Dialog dynamically updates fields to match active entity.", td_style),
            Paragraph("Status: <i>Show/hide MSPhysics UI</i>", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/toggle_play.png', width=16, height=16), Paragraph("<b>Toggle Play</b>", td_bold)]], colWidths=[20, 70]),
            Paragraph("Global Sim Engine<br/>State: Play / Pause", td_style),
            Paragraph("Initiates real-time physics simulation across the entire model. Every top-level group/component becomes an active dynamic body.", td_style),
            Paragraph("1. Verify model geometry is grouped.<br/>2. Click button to launch simulation.<br/>3. Click again mid-sim to freeze/pause solver; click to resume.", td_style),
            Paragraph("Status: <i>Play/Pause simulation (all groups)</i>", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/reset.png', width=16, height=16), Paragraph("<b>Reset</b>", td_bold)]], colWidths=[20, 70]),
            Paragraph("Reversion Tool<br/>State: Active during Sim", td_style),
            Paragraph("Terminates simulation, restores all moved bodies back to their exact pre-simulation transformations, and destroys emitted dynamic copies.", td_style),
            Paragraph("1. Click at any time during or after paused simulation.<br/>2. Physics engine clears memory and resets model state.", td_style),
            Paragraph("Status: <i>End simulation and reset positions</i>", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/toggle_play2.png', width=16, height=16), Paragraph("<b>Toggle Play 2</b><br/>(Selective)", td_bold)]], colWidths=[20, 70]),
            Paragraph("Selective Engine<br/>State: Selection Active", td_style),
            Paragraph("Starts simulation ONLY from highlighted groups/components. All non-selected entities are automatically treated as stationary/static obstacles.", td_style),
            Paragraph("1. Use SketchUp Select tool to highlight specific bodies.<br/>2. Click Toggle Play 2.<br/>3. Only selection moves; prevents lagging in giant scenes.", td_style),
            Paragraph("Status: <i>Play/Pause from selected groups</i>", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/stop.png', width=16, height=16), Paragraph("<b>Stop</b><br/>(Freeze Poses)", td_bold)]], colWidths=[20, 70]),
            Paragraph("State Baker Tool<br/>State: Active during Sim", td_style),
            Paragraph("Haults simulation WITHOUT restoring initial positions and WITHOUT deleting emitted bodies. Bakes final physics poses into the SketchUp model.", td_style),
            Paragraph("1. Run simulation until objects settle naturally (e.g. falling rocks, dumped gravel, draped ropes).<br/>2. Click Stop to keep final layout permanently.", td_style),
            Paragraph("Status: <i>End simulation keeping positions</i>", td_style)
        ],
    ]
    sim_table = Table(sim_tools_data, colWidths=[95, 75, 140, 160, 70])
    sim_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, ALT_ROW]),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(sim_table)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Live In-Simulation Interactive Tools & Viewport Manipulation", h2_style))
    interact_data = [
        [
            Table([[Image('MSPhysics/images/cursors/grab.png', width=14, height=15), Paragraph("<b>Interactive Mouse Drag Tool</b>", td_bold)]], colWidths=[18, 242]),
            Table([[Image('MSPhysics/images/cursors/target.png', width=14, height=14), Paragraph("<b>6-DOF Flight & Walk Camera</b>", td_bold)]], colWidths=[18, 242])
        ],
        [
            Paragraph("While simulation is running, <b>Left-Click and Drag</b> any dynamic body in 3D viewport. "
                      "A virtual spring attaches from cursor hit point to body surface, applying real physical pulling force. "
                      "Holding <b>SHIFT</b> while dragging applies rotational torque, allowing interactive orientation tilting.", td_style),
            Paragraph("Navigate viewport freely during active physics without interrupting solver:<br/>"
                      "• <b>W / S:</b> Fly forward / backward | <b>A / D:</b> Strafe left / right<br/>"
                      "• <b>Q / E:</b> Elevate up / down | <b>Arrow Keys:</b> Pan / tilt camera look-at angle<br/>"
                      "• <b>CTRL + Left/Right Arrow:</b> Roll camera clockwise / counter-clockwise.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/ui.png', width=14, height=14), Paragraph("<b>On-Screen Control Panel Sliders</b>", td_bold)]], colWidths=[18, 242]),
            Table([[Image('MSPhysics/images/cursors/click.png', width=14, height=15), Paragraph("<b>Right-Click Context Menu Tools</b>", td_bold)]], colWidths=[18, 242])
        ],
        [
            Paragraph("When any joint or thruster controller uses <code>slider(name, default, min, max)</code>, "
                      "MSPhysics generates an on-screen HUD window with graphical sliders. "
                      "Users drag sliders in real-time to steer wheels, articulate robotic arms, or control thrusters.", td_style),
            Paragraph("Right-clicking any group/component in SketchUp provides instant access to <b>MSPhysics</b> context submenus:<br/>"
                      "• <b>State:</b> Toggle Static, Frozen, Ignored, Collidable, Auto Sleep, Continuous Collision, Gravity, Magnetic.<br/>"
                      "• <b>Shape:</b> Override collision primitive | <b>Material:</b> Assign friction presets.", td_style)
        ]
    ]
    interact_tbl = Table(interact_data, colWidths=[270, 270])
    interact_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), LIGHT_BG),
        ('BACKGROUND', (1,0), (1,0), LIGHT_BG),
        ('BACKGROUND', (0,2), (0,2), LIGHT_BG),
        ('BACKGROUND', (1,2), (1,2), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(interact_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Simulation Engine Solver Loop & Performance Tuning", h2_style))
    loop_data = [
        [
            Paragraph("<b>Phase 1: Input & Event Ingestion</b>", td_bold),
            Paragraph("<b>Phase 2: Controller & Force Eval</b>", td_bold),
            Paragraph("<b>Phase 3: Newton Substepping</b>", td_bold),
            Paragraph("<b>Phase 4: Viewport Synchronization</b>", td_bold)
        ],
        [
            Paragraph("AMS Library polls Windows message loop, intercepting async keystrokes, mouse spring coordinates, and UI slider adjustments.", td_style),
            Paragraph("Evaluates all Ruby controller expressions, thruster force vectors, and magnetic field equations before solver integration.", td_style),
            Paragraph("Newton Dynamics executes iterative LCP constraint solver (60–240 Hz), resolving joint kinematics, friction, and CCD contacts.", td_style),
            Paragraph("Transforms calculated by C++ engine are pushed into SketchUp Group transformations; camera positions updated.", td_style)
        ]
    ]
    loop_tbl = Table(loop_data, colWidths=[135, 135, 135, 135])
    loop_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), ALT_ROW),
        ('BACKGROUND', (0,1), (-1,1), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(loop_tbl)
    story.append(Spacer(1, 2))

    # Page 2 Addition: Solver Optimization & Stability Advice
    stab_html = (
        "<b>Solver Stability & Optimization Pro-Tips:</b><br/>"
        "• <b>Substepping:</b> If high-speed mechanisms explode or jitter, increase <i>Update Rate</i> to 120Hz or 240Hz in the Simulation UI tab.<br/>"
        "• <b>Continuous Collision Detection (CCD):</b> Always enable CCD for fast-moving small projectiles or thin wall boundaries to prevent tunneling.<br/>"
        "• <b>Auto Sleep:</b> Keep Auto Sleep enabled so resting bodies deactivate solver calculations, freeing CPU cycles for moving bodies."
    )
    stab_tbl = Table([[Paragraph(stab_html, callout_text)]], colWidths=[540])
    stab_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.6, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(stab_tbl)

    story.append(PageBreak())

    # =========================================================================
    # PAGE 3: JOINT CONNECTION TOOL & GEAR TRANSMISSIONS
    # =========================================================================
    story.append(make_banner("SECTION 2: JOINT CONNECTION TOOL & GEAR TRANSMISSIONS", "KINEMATIC BINDING"))
    story.append(Spacer(1, 2))

    conn_intro = (
        "In MSPhysics, <b>joint placement is strictly decoupled from joint connection</b>. "
        "Simply inserting a joint component next to a body does <i>not</i> constrain it. "
        "The <b>Joint Connection Tool</b> establishes the mathematical parent-child linkage between rigid bodies and constraint frames. "
        "Furthermore, the <b>Gear Connection Tool</b> couples multiple joints with transmission gear ratios for mechanical engineering."
    )
    story.append(Paragraph(conn_intro, body_style))
    story.append(Spacer(1, 2))

    story.append(Paragraph("The Joint Connection Tool & Modifier Key Architecture", h2_style))
    conn_guide_data = [
        [Paragraph("Modifier Key", th_style), Paragraph("Cursor Graphic", th_style), Paragraph("Action Mode", th_style), Paragraph("Operational Procedure & Mouse Interaction", th_style), Paragraph("Viewport Visual Indicator", th_style)],
        [
            Paragraph("<b>None (Default)</b>", td_bold),
            Image('MSPhysics/images/cursors/select.png', width=14, height=17),
            Paragraph("<b>Select Entity</b>", td_bold),
            Paragraph("Click on any body (group/component) or joint to make it active selected entity. Prepares entity for connection.", td_style),
            Paragraph("<font color='#1E3A8A'><b>Solid Blue Outline:</b></font><br/>Selected entity in memory.", td_style)
        ],
        [
            Paragraph("<b>CTRL</b>", td_bold),
            Image('MSPhysics/images/cursors/select_plus.png', width=14, height=17),
            Paragraph("<b>Connect (+)</b>", td_bold),
            Paragraph("While a body is selected, hold <b>CTRL</b> and click a Joint to bind them. Alternatively, select a joint and Ctrl-click child bodies.", td_style),
            Paragraph("<font color='#15803D'><b>Solid Green Outline:</b></font><br/>Connected joint or child body.", td_style)
        ],
        [
            Paragraph("<b>SHIFT</b>", td_bold),
            Image('MSPhysics/images/cursors/select_minus.png', width=14, height=17),
            Paragraph("<b>Disconnect (-)</b>", td_bold),
            Paragraph("While a body is selected, hold <b>SHIFT</b> and click an already connected joint to sever kinematic constraint linkage.", td_style),
            Paragraph("<font color='#DC2626'><b>Red Selection Cue:</b></font><br/>Connection severed.", td_style)
        ],
        [
            Paragraph("<b>CTRL + SHIFT</b>", td_bold),
            Image('MSPhysics/images/cursors/select_plus_minus.png', width=14, height=17),
            Paragraph("<b>Toggle (+/-)</b>", td_bold),
            Paragraph("Hold both keys simultaneously and click any target joint to invert connection state (connects if severed; severs if connected).", td_style),
            Paragraph("<font color='#D97706'><b>Adaptive Toggle:</b></font><br/>Swaps active connection state.", td_style)
        ]
    ]
    conn_tbl = Table(conn_guide_data, colWidths=[70, 45, 75, 230, 120])
    conn_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, ALT_ROW]),
        ('TOPPADDING', (0,0), (-1,-1), 1.8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.8),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ALIGN', (1,0), (1,-1), 'CENTER'),
    ]))
    story.append(conn_tbl)
    story.append(Spacer(1, 2))

    multi_html = (
        "<b>Component Multi-Instance Propagation:</b> When connecting a joint to a SketchUp Component Instance that possesses multiple copies in the model, "
        "MSPhysics detects the shared ComponentDefinition and displays a dialog: <i>'Would you like to connect/disconnect this joint to/from all alike instances?'</i><br/>"
        "• Clicking <b>YES</b> replicates the joint constraint across every identical instance automatically (e.g. four vehicle wheels).<br/>"
        "• Clicking <b>NO</b> establishes a unique connection for only the clicked instance."
    )
    multi_tbl = Table([[Paragraph(multi_html, callout_text)]], colWidths=[540])
    multi_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), AMBER_BG),
        ('BOX', (0,0), (-1,-1), 0.8, ACCENT),
        ('TOPPADDING', (0,0), (-1,-1), 2.2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2.2),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(multi_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("The Gear Connection Tool & Transmission Kinematics", h2_style))
    gear_data = [
        [
            Paragraph("<b>Transmission Theory & Ratio Formula</b>", td_bold),
            Paragraph("<b>Step-by-Step Gear Pairing Workflow</b>", td_bold)
        ],
        [
            Paragraph("Gears mathematically couple degrees of freedom between two separate joints:<br/>"
                      "• <b>Rotational to Rotational:</b> Speed2 = -Ratio * Speed1 (Spur gears, planetary sets)<br/>"
                      "• <b>Rotational to Linear:</b> Velocity2 = Ratio * Omega1 (Rack & pinion, lead screws)<br/>"
                      "• <b>Linear to Linear:</b> Velocity2 = Ratio * Velocity1 (Scissor linkages)<br/>"
                      "<b>Supported Joints:</b> Hinge, Motor, Servo, Slider, Piston, Spring, CurvySlider, CurvyPiston.", td_style),
            Paragraph("1. Ensure both bodies are top-level and each is connected to at least one supported joint.<br/>"
                      "2. Activate the <b>Gear Connection Tool</b>.<br/>"
                      "3. Click instance A (turns Blue); hold <b>CTRL/SHIFT</b> and click instance B (turns Green).<br/>"
                      "4. Open <b>MSPhysics UI -> Joint Tab -> Gears section</b>.<br/>"
                      "5. Enter desired <b>Gear Ratio</b> (positive for matching; negative for counter-rotation).", td_style)
        ]
    ]
    gear_tbl = Table(gear_data, colWidths=[270, 270])
    gear_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), LIGHT_BG),
        ('BACKGROUND', (1,0), (1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 1.8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.8),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(gear_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Joint Connection Rules & Mechanical Archetypes Matrix", h2_style))
    rules_data = [
        [Paragraph("Mechanism Type", th_style), Paragraph("Joint Combination", th_style), Paragraph("Gear Ratio Formula", th_style), Paragraph("Engineering Setup & Practical Guidance", th_style)],
        [
            Paragraph("<b>Spur Gear Reduction</b>", td_bold),
            Paragraph("Hinge A + Hinge B", td_style),
            Paragraph("<code>Ratio = -(Teeth A / Teeth B)</code>", td_code),
            Paragraph("Negative sign forces counter-rotation. Place hinges at exact pitch circle centers.", td_style)
        ],
        [
            Paragraph("<b>Rack and Pinion</b>", td_bold),
            Paragraph("Hinge A + Slider B", td_style),
            Paragraph("<code>Ratio = Radius (meters)</code>", td_code),
            Paragraph("Couples rotating pinion gear to linearly translating rack rail. Used for steering.", td_style)
        ],
        [
            Paragraph("<b>Mechanical Scissor Lift</b>", td_bold),
            Paragraph("Slider A + Slider B", td_style),
            Paragraph("<code>Ratio = -1.0</code>", td_code),
            Paragraph("Symmetrically couples left and right sliding pins, ensuring balanced vertical lift.", td_style)
        ],
        [
            Paragraph("<b>Compound Differential</b>", td_bold),
            Paragraph("Motor + 2 Hinges", td_style),
            Paragraph("<code>Omega_M = 0.5*(W_L + W_R)</code>", td_code),
            Paragraph("Allows drive wheels to rotate at differing speeds during vehicle cornering.", td_style)
        ]
    ]
    rules_tbl = Table(rules_data, colWidths=[110, 95, 125, 210])
    rules_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, LIGHT_BG]),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(rules_tbl)
    story.append(Spacer(1, 2))

    # Page 3 Addition: Integrity Rules Callout
    rules_callout = (
        "<b>Joint Connection Integrity Rules:</b> "
        "(1) <i>Connecting to Self:</i> A body cannot be connected to itself (raises warning). "
        "(2) <i>Interconnecting Bodies:</i> Directly connecting Body to Body without an intermediate joint is prohibited. "
        "(3) <i>Ignored Bodies:</i> Connecting to an ignored body or a joint inside an ignored body is disallowed. "
        "(4) <i>Articulated Chains:</i> To create robotic arms or excavators, nest the joint inside the parent body group; connect child body to it."
    )
    rules_callout_tbl = Table([[Paragraph(rules_callout, callout_text)]], colWidths=[540])
    rules_callout_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.6, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(rules_callout_tbl)

    story.append(PageBreak())

    # =========================================================================
    # PAGE 4: JOINT CREATION TOOLS — ROTATIONAL & LINEAR ACTUATORS
    # =========================================================================
    story.append(make_banner("SECTION 3: JOINT CREATION TOOLS — ROTATIONAL & LINEAR ACTUATORS", "ACTUATORS & RAILS"))
    story.append(Spacer(1, 2))

    joint_intro = (
        "MSPhysics features 14 specialized parametric joint types. Every joint is placed via a 2-point vector sequence: "
        "<b>Point 1 sets the joint's anchor origin</b>; <b>Point 2 defines its primary constraint direction</b> (represented by the Blue axis). "
        "Exact dimensions can be entered in SketchUp's Measurements (VCB) box. "
        "Below is the complete engineering specification for the 7 primary rotational and linear actuator joints."
    )
    story.append(Paragraph(joint_intro, body_style))
    story.append(Spacer(1, 2))

    joints_part1 = [
        [Paragraph("Joint & Icon", th_style), Paragraph("DOFs & Type", th_style), Paragraph("Mechanical Applications", th_style), Paragraph("Key Parameters & Limits", th_style), Paragraph("Controller Formula & Expressions", th_style)],
        [
            Table([[Image('MSPhysics/images/icons/hinge.png', width=15, height=15), Paragraph("<b>Hinge</b>", td_bold)]], colWidths=[18, 67]),
            Paragraph("<b>1 DOF:</b><br/>Rotation around Blue Z-axis", td_style),
            Paragraph("Doors, cabinet flaps, wheels, pendulums, robotic elbows, casters, levers.", td_style),
            Paragraph("• Min/Max angle limits (-180° to +180°)<br/>• Angular friction & damping<br/>• Spring stiffness & rest angle", td_style),
            Paragraph("Motorized hinge controller:<br/><code>slider('hinge', 0, -90, 90)</code>", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/motor.png', width=15, height=15), Paragraph("<b>Motor</b>", td_bold)]], colWidths=[18, 67]),
            Paragraph("<b>1 DOF:</b><br/>Powered continuous rotation", td_style),
            Paragraph("Propellers, car wheels, cooling fan turbines, saw blades, conveyor rollers.", td_style),
            Paragraph("• Target speed (rad/s or deg/s)<br/>• Acceleration & max torque<br/>• Free-wheeling when controller is 0", td_style),
            Paragraph("Dynamic speed controller:<br/><code>15.0 * (key('w') - key('s'))</code>", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/servo.png', width=15, height=15), Paragraph("<b>Servo</b>", td_bold)]], colWidths=[18, 67]),
            Paragraph("<b>1 DOF:</b><br/>Target angle positioner", td_style),
            Paragraph("Steering knuckles, aircraft ailerons/rudders, robotic arms, pan/tilt gimbals.", td_style),
            Paragraph("• Angular sweep limits<br/>• Max angular rate (deg/s)<br/>• Power/holding torque limit", td_style),
            Paragraph("Target angle in degrees:<br/><code>35 * (key('right') - key('left'))</code>", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/slider.png', width=15, height=15), Paragraph("<b>Slider</b>", td_bold)]], colWidths=[18, 67]),
            Paragraph("<b>1 DOF:</b><br/>Linear passive translation", td_style),
            Paragraph("Drawers, sliding glass doors, crane gantries, elevator guide tracks.", td_style),
            Paragraph("• Linear Min/Max limits (meters)<br/>• Linear friction coefficient<br/>• Linear spring stiffness & damping", td_style),
            Paragraph("Passive constraint by default. Acts as spring buffer when spring parameters > 0.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/piston.png', width=15, height=15), Paragraph("<b>Piston</b>", td_bold)]], colWidths=[18, 67]),
            Paragraph("<b>1 DOF:</b><br/>Powered linear actuator", td_style),
            Paragraph("Hydraulic/pneumatic rams, dump truck lifters, elevator pistons, jacks.", td_style),
            Paragraph("• Stroke length limits (Min/Max)<br/>• Linear travel speed (m/s)<br/>• Push/pull max force (Newtons)", td_style),
            Paragraph("Target position along stroke:<br/><code>slider('lift', 0, 0, 2.5)</code>", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/spring.png', width=15, height=15), Paragraph("<b>Spring</b>", td_bold)]], colWidths=[18, 67]),
            Paragraph("<b>1 DOF:</b><br/>Elastic linear or torsional motion", td_style),
            Paragraph("Vehicle suspension struts, pogo sticks, trampoline springs, recoil buffers.", td_style),
            Paragraph("• Stiffness k (N/m)<br/>• Damping c (N·s/m)<br/>• Rest distance & travel bounds", td_style),
            Paragraph("Hooke's Law: F = -k(x - x0) - c*v. Tuned in Joint UI tab.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/corkscrew.png', width=15, height=15), Paragraph("<b>Corkscrew</b>", td_bold)]], colWidths=[18, 67]),
            Paragraph("<b>2 Coupled DOFs:</b><br/>Simultaneous slide & twist", td_style),
            Paragraph("Threaded bolt screws, spiral augers, spiral ramps, screw bottle caps.", td_style),
            Paragraph("• Pitch (travel distance per 360° turn)<br/>• Linear bounds & angular limits<br/>• Rotational & linear friction", td_style),
            Paragraph("Coupled motion constraint: Delta Z = Pitch * (Delta Theta / 2pi).", td_style)
        ],
    ]
    joints_tbl1 = Table(joints_part1, colWidths=[85, 75, 125, 125, 130])
    joints_tbl1.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, ALT_ROW]),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(joints_tbl1)
    story.append(Spacer(1, 2))

    align_html = (
        "<b>Joint Coordinate Axes Convention:</b> Each joint visual gizmo displays colored Cartesian axes. "
        "<b>Blue represents the primary constraint axis</b> (the axis of rotation for Hinge/Motor/Servo; the axis of slide for Slider/Piston). "
        "<b>Red and Green represent constraint limits and zero-reference planes</b>. "
        "Ensure the Blue axis is precisely aligned with your intended axle or guide track before connecting."
    )
    align_tbl = Table([[Paragraph(align_html, callout_text)]], colWidths=[540])
    align_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), BLUE_BG),
        ('BOX', (0,0), (-1,-1), 0.8, SECONDARY),
        ('TOPPADDING', (0,0), (-1,-1), 2.2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2.2),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(align_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Dynamic Controller Expressions Syntax & Functions", h2_style))
    syntax_data = [
        [Paragraph("Expression Syntax Pattern", th_style), Paragraph("Input Context", th_style), Paragraph("Mathematical Behavior", th_style), Paragraph("Typical Robotic / Mechanical Use Case", th_style)],
        [
            Paragraph("<code>slider('name', def, min, max)</code>", td_code),
            Paragraph("Control Panel HUD", td_style),
            Paragraph("Exposes on-screen real-time graphical slider returning float between min and max.", td_style),
            Paragraph("Manual steering, crane boom angle, valve throttling, variable speed.", td_style)
        ],
        [
            Paragraph("<code>val * (key('w') - key('s'))</code>", td_code),
            Paragraph("Keyboard Polling", td_style),
            Paragraph("Returns +val on 'w', -val on 's', and 0.0 when neither or both are pressed.", td_style),
            Paragraph("Forward / reverse vehicle drive, hoist lift, bidirectional motors.", td_style)
        ],
        [
            Paragraph("<code>amp * sin(2 * PI * freq * time)</code>", td_code),
            Paragraph("Oscillator Math", td_style),
            Paragraph("Generates continuous harmonic sinusoidal oscillation as time advances.", td_style),
            Paragraph("Windshield wipers, pendulum clock escapement, walking gait animators.", td_style)
        ],
        [
            Paragraph("<code>joystick(:left_y) * 100</code>", td_code),
            Paragraph("Game Controller", td_style),
            Paragraph("Reads analog joystick axis value (-1.0 to +1.0) with proportional sensitivity.", td_style),
            Paragraph("Precision flight simulator yoke, analog gamepad throttle and steering.", td_style)
        ]
    ]
    syntax_tbl = Table(syntax_data, colWidths=[130, 90, 155, 165])
    syntax_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, LIGHT_BG]),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(syntax_tbl)
    story.append(Spacer(1, 2))

    # Page 4 Addition: Kinematic Chain Architecture
    chain_html = (
        "<b>Articulated Kinematic Chains & Hierarchy Guidelines:</b> "
        "To build multi-segment robot arms, backhoes, or folding landing gear, do not leave all joints at top-level world space. "
        "Instead, group Joint 2 inside Body 1's group; then connect Body 2 to Joint 2. "
        "This embeds Joint 2's frame of reference into Body 1's moving local coordinate space, creating robust compound kinematic linkages."
    )
    chain_tbl = Table([[Paragraph(chain_html, callout_text)]], colWidths=[540])
    chain_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.6, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(chain_tbl)

    story.append(PageBreak())

    # =========================================================================
    # PAGE 5: JOINT CREATION TOOLS — SPATIAL CONSTRAINTS & PATHS
    # =========================================================================
    story.append(make_banner("SECTION 4: JOINT CREATION TOOLS — SPATIAL CONSTRAINTS & PATHS", "SPATIAL & PATH CONSTRAINTS"))
    story.append(Spacer(1, 2))

    spatial_intro = (
        "Complex mechanisms require multi-dimensional spatial constraints, spherical pivots, planar glides, or path-following trajectories. "
        "MSPhysics includes sophisticated joint geometries capable of binding bodies along arbitrary 3D curves or stabilizing multi-axis orientations. "
        "This section covers the remaining 7 joint types plus the Joint Scaling tool."
    )
    story.append(Paragraph(spatial_intro, body_style))
    story.append(Spacer(1, 2))

    joints_part2 = [
        [Paragraph("Joint & Icon", th_style), Paragraph("DOFs & Type", th_style), Paragraph("Mechanical Applications", th_style), Paragraph("Key Parameters & Settings", th_style), Paragraph("Setup Guide & Placement Notes", th_style)],
        [
            Table([[Image('MSPhysics/images/icons/ball_and_socket.png', width=15, height=15), Paragraph("<b>BallAndSocket</b>", td_bold)]], colWidths=[18, 72]),
            Paragraph("<b>3 DOFs:</b><br/>Spherical omnidirectional rotation", td_style),
            Paragraph("Automotive tie-rods, suspension wishbones, anatomical shoulders/hips, trailer hitches.", td_style),
            Paragraph("• Max cone cone-angle limit<br/>• Axial twist limits (Min/Max)<br/>• Joint friction & damping", td_style),
            Paragraph("Place center at the pivot sphere origin. Aligns freely in 3D space.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/universal.png', width=15, height=15), Paragraph("<b>Universal</b>", td_bold)]], colWidths=[18, 72]),
            Paragraph("<b>2 DOFs:</b><br/>Orthogonal angular rotation", td_style),
            Paragraph("Cardan drive shaft couplings, mechanical gyroscope rings, wrist articulations.", td_style),
            Paragraph("• Min/Max angle for Axis 1<br/>• Min/Max angle for Axis 2<br/>• Rotational friction", td_style),
            Paragraph("Place at the cross-pivot intersection of the two rotational yokes.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/fixed.png', width=15, height=15), Paragraph("<b>Fixed</b>", td_bold)]], colWidths=[18, 72]),
            Paragraph("<b>0 DOFs:</b><br/>Rigid structural weld", td_style),
            Paragraph("Rigidly locking two dynamic bodies together, or welding a body immovably to world space.", td_style),
            Paragraph("• Breakable max linear force (N)<br/>• Breakable max torque (N·m)<br/>• Rigid lock when breakable is 0", td_style),
            Paragraph("Place anywhere on contact plane. Snaps under extreme impact if breakable is set.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/plane.png', width=15, height=15), Paragraph("<b>Plane</b>", td_bold)]], colWidths=[18, 72]),
            Paragraph("<b>3 DOFs:</b><br/>2 Linear (X/Y) + 1 Rotational (Z)", td_style),
            Paragraph("Air hockey pucks, hovercraft, furniture gliding on flat floors, planar XY pantographs.", td_style),
            Paragraph("• Linear surface friction<br/>• Angular surface friction<br/>• Strict normal axis constraint", td_style),
            Paragraph("Align Blue Z-axis perpendicular to the sliding surface plane.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/curvy_slider.png', width=15, height=15), Paragraph("<b>CurvySlider</b>", td_bold)]], colWidths=[18, 72]),
            Paragraph("<b>1 Path DOF:</b><br/>Passive sliding along 3D spline", td_style),
            Paragraph("Rollercoasters, overhead factory conveyor rails, train tracks, curtain tracks.", td_style),
            Paragraph("• Loop path mode (cyclic)<br/>• Linear friction along curve<br/>• Alignment: Lock orientation to tangent", td_style),
            Paragraph("1. Group a continuous chain of edges.<br/>2. Insert CurvySlider at curve origin.<br/>3. Connect body with Connection Tool.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/curvy_piston.png', width=15, height=15), Paragraph("<b>CurvyPiston</b>", td_bold)]], colWidths=[18, 72]),
            Paragraph("<b>1 Path DOF:</b><br/>Powered drive along 3D spline", td_style),
            Paragraph("Automated cable cars, camera motion dollies along splines, automated guided vehicles (AGV).", td_style),
            Paragraph("• Target position along path<br/>• Speed & drive power limit<br/>• Loop mode & curve alignment", td_style),
            Paragraph("Controller drives distance along curve length:<br/><code>slider('track_pos', 0, 0, 50)</code>", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/up_vector.png', width=15, height=15), Paragraph("<b>UpVector</b>", td_bold)]], colWidths=[18, 72]),
            Paragraph("<b>Orientation Lock:</b><br/>Restricts pitch and roll", td_style),
            Paragraph("Self-balancing rovers, speedboats, hovercraft, upright walking biped characters.", td_style),
            Paragraph("• Max correction torque<br/>• Angular damping<br/>• Target world vector ([0, 0, 1])", td_style),
            Paragraph("Prevents dynamic bodies from tipping or flipping over during aggressive motions.", td_style)
        ],
    ]
    joints_tbl2 = Table(joints_part2, colWidths=[90, 75, 125, 125, 125])
    joints_tbl2.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, ALT_ROW]),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(joints_tbl2)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Scale MSPhysics Joints Tool & Distance Constraints", h2_style))
    scale_data = [
        [
            Table([[Image('MSPhysics/images/icons/scale_joints.png', width=15, height=15), Paragraph("<b>Scale MSPhysics Joints Tool</b>", td_bold)]], colWidths=[18, 244]),
            Paragraph("<b>Point-to-Point & Cable Constraints</b>", td_bold)
        ],
        [
            Paragraph("In large architectural models or miniature mechanical watches, joint gizmos may appear too small or too large. "
                      "Activating <b>Scale MSPhysics Joints</b> displays an input prompt to rescale joint visual geometry (from 0.05x to 10.0x).<br/>"
                      "<b>Crucial Invariance Note:</b> Rescaling joints modifies <i>only</i> visual viewport representation. "
                      "It does <b>not</b> change physical mass, stiffness, damping, limits, or solver behavior.", td_style),
            Paragraph("<b>PointToPoint (Joint ID 15):</b> A spherical tether constraint that maintains a fixed distance between two anchor points in space "
                      "while allowing unrestricted 3-axis angular freedom. "
                      "Used for suspension chains, crane hoisting cables, bridge stays, and flexible fabric links. "
                      "Configurable with breaking tension limits.", td_style)
        ]
    ]
    scale_tbl = Table(scale_data, colWidths=[270, 270])
    scale_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), LIGHT_BG),
        ('BACKGROUND', (1,0), (1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 1.8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.8),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(scale_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Curvy Spline Construction & Structural Failure Mechanics", h2_style))
    path_data = [
        [
            Paragraph("<b>Curvy Spline Edge Chain Construction</b>", td_bold),
            Paragraph("<b>Breakable Constraints & Crash Destruction</b>", td_bold)
        ],
        [
            Paragraph("1. Create a continuous chain of connected SketchUp Edges or Arcs.<br/>"
                      "2. Group the curve geometry. Curvy joints read vertex sequences within the group.<br/>"
                      "3. Insert <b>CurvySlider</b> or <b>CurvyPiston</b> at the initial starting vertex.<br/>"
                      "4. In UI, check <i>Loop</i> for closed circuits, or set tangent alignment to prevent car derailment.", td_style),
            Paragraph("Joints can be configured to simulate catastrophic structural failure under excessive shock:<br/>"
                      "• <b>Breakable Force (N):</b> Snaps joint if linear tension/shear exceeds threshold.<br/>"
                      "• <b>Breakable Torque (N·m):</b> Snaps joint if bending moment exceeds threshold.<br/>"
                      "Essential for bridge collapse tests, breakaway bolts, and crumple zones.", td_style)
        ]
    ]
    path_tbl = Table(path_data, colWidths=[270, 270])
    path_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), ALT_ROW),
        ('BACKGROUND', (1,0), (1,0), ALT_ROW),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white]),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(path_tbl)
    story.append(Spacer(1, 2))

    # Page 5 Addition: Vehicle Chassis Assembly
    veh_html = (
        "<b>Vehicle Chassis & Suspension Assembly Pattern:</b> "
        "A typical 4-wheel vehicle uses a main Chassis Body. At each wheel position, insert a vertical <b>Spring</b> joint (suspension travel). "
        "Attach a steering knuckle body to the spring bottom with a <b>Servo</b> joint (steering angle). "
        "Finally, connect the wheel to the servo knuckle with a <b>Motor</b> joint (drive torque). "
        "Add an <b>UpVector</b> to the chassis if necessary to eliminate rollover on extreme slopes."
    )
    veh_tbl = Table([[Paragraph(veh_html, callout_text)]], colWidths=[540])
    veh_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.6, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(veh_tbl)

    story.append(PageBreak())

    # =========================================================================
    # PAGE 6: MSPHYSICS UI DIALOG & INSPECTOR TOOLS
    # =========================================================================
    story.append(make_banner("SECTION 5: MSPHYSICS UI DIALOG & INSPECTOR TOOLS", "INSPECTION & SCRIPTING"))
    story.append(Spacer(1, 2))

    ui_intro = (
        "The <b>MSPhysics UI Dialog</b> (launched via Toggle UI) is an interactive, multi-tabbed web-based inspector. "
        "It communicates bidirectionally with SketchUp's Ruby core to configure world physics, body properties, joint parameters, "
        "custom programmatic behaviors, thruster/emitter engines, and 3D spatial audio."
    )
    story.append(Paragraph(ui_intro, body_style))
    story.append(Spacer(1, 2))

    tabs_data = [
        [Paragraph("Inspector Tab", th_style), Paragraph("Target Domain", th_style), Paragraph("Key Configurable Properties & Settings", th_style), Paragraph("Operational Instructions & Best Practices", th_style)],
        [
            Paragraph("<b>Tab 1: Simulation</b>", td_bold),
            Paragraph("World Environment & Solver Settings", td_style),
            Paragraph("• <b>Gravity Vector:</b> Global X, Y, Z acceleration (default: -9.8 m/s² along Z)<br/>"
                      "• <b>Continuous Collision (CCD):</b> Eliminates high-speed tunneling<br/>"
                      "• <b>Update Rate & Substeps:</b> 60Hz, 120Hz, 240Hz solver frequency<br/>"
                      "• <b>Visual Debuggers:</b> Collision Wireframe, Center of Mass axes, Bounding Boxes, Contact Points & Force vectors.", td_style),
            Paragraph("Enable <b>Collision Wireframe</b> to inspect how Newton Dynamics sees your geometry. Increase Update Rate to 120/240Hz for stiff mechanisms or fast vehicles.", td_style)
        ],
        [
            Paragraph("<b>Tab 2: Properties</b>", td_bold),
            Paragraph("Body Mesh, Mass, Thrusters & Emitters", td_style),
            Paragraph("• <b>10 Collision Shapes:</b> Box, Sphere, Cone, Cylinder, Capsule, Chamfer Cylinder, Convex Hull, Compound, Compound from CD, Null<br/>"
                      "• <b>Mass Control:</b> By Mass (kg) or by Density (g/cm³)<br/>"
                      "• <b>Material Properties:</b> Static/Kinetic Friction, Elasticity, Softness<br/>"
                      "• <b>Magnetic Force & Range:</b> Attract, Repel, or Dipole modes<br/>"
                      "• <b>Thruster Engine:</b> Directional force vector with controller<br/>"
                      "• <b>Emitter Cannon:</b> Spawns copies of body at rate, speed, lifetime.", td_style),
            Paragraph("Always prefer <b>Primitives</b> (Box, Cylinder) or <b>Convex Hull</b> over complex meshes for massive performance gains. Use <b>Compound from CD</b> for assemblies with internal holes.", td_style)
        ],
        [
            Paragraph("<b>Tab 3: Joint</b>", td_bold),
            Paragraph("Joint Limits & Controllers", td_style),
            Paragraph("• <b>Kinematic Limits:</b> Min/Max angles, stroke distances<br/>"
                      "• <b>Controllers:</b> Dynamic mathematical formulas and key bindings<br/>"
                      "• <b>Friction & Springs:</b> Angular/linear damping and stiffness<br/>"
                      "• <b>Breakable Thresholds:</b> Force and torque break limits.", td_style),
            Paragraph("Select any joint in the model to reveal its dedicated tuning panel. Write expressions like <code>1000 * key('space')</code> into the Controller field.", td_style)
        ],
        [
            Paragraph("<b>Tab 4: Script</b>", td_bold),
            Paragraph("Ruby Scripting IDE & Event Callbacks", td_style),
            Paragraph("Embedded Ace Code Editor with Ruby syntax highlighting.<br/>"
                      "<b>Lifecycle Event Hooks:</b><br/>"
                      "• <code>onStart { ... }</code>: Runs once upon simulation start<br/>"
                      "• <code>onUpdate { ... }</code>: Runs every frame before physics step<br/>"
                      "• <code>onPostUpdate { ... }</code>: Runs after physics integration<br/>"
                      "• <code>onTouch(contact) { ... }</code>: Triggered on collision<br/>"
                      "• <code>onUntouch(contact) { ... }</code>: Triggered when contact ends<br/>"
                      "• <code>onDestroy { ... }</code>: Cleanup when simulation terminates.", td_style),
            Paragraph("Use full access to MSPhysics Body API: <code>body.set_velocity(vec)</code>, <code>body.add_force(f)</code>, <code>body.set_color(c)</code>. Script errors are cleanly reported in console.", td_style)
        ],
        [
            Paragraph("<b>Tab 5: Sound</b>", td_bold),
            Paragraph("SDL2 Mixer Audio System", td_style),
            Paragraph("• Supports WAV, MP3, OGG, FLAC, AIFF, MIDI<br/>"
                      "• <b>3D Positional Audio:</b> Spatial falloff, stereo panning, Doppler effect<br/>"
                      "• Volume, pitch, and distance attenuation controls.", td_style),
            Paragraph("Trigger sounds on collision events or controller thresholds: <code>simulation.play_sound('boom.wav', body.get_position)</code>.", td_style)
        ],
    ]
    tabs_tbl = Table(tabs_data, colWidths=[80, 85, 215, 160])
    tabs_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, ALT_ROW]),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(tabs_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Thruster Vector Engine & Emitter Projectile System", h2_style))
    prop_data = [
        [
            Paragraph("<b>Thruster Engine Configuration</b>", td_bold),
            Paragraph("<b>Emitter Projectile Cannon System</b>", td_bold)
        ],
        [
            Paragraph("Thrusters apply dynamic force vectors to their associated bodies in real time:<br/>"
                      "• <b>Controller Input:</b> Number in Newtons (e.g. <code>500</code>) or 3D vector <code>[Fx, Fy, Fz]</code>.<br/>"
                      "• <b>Lock to Body Axes:</b> When enabled, force rotates along with body (jet engines, rockets). When disabled, force acts in global world directions.<br/>"
                      "• <b>Steering:</b> Combine with keys: <code>[1000*key('w'), 0, 500*key('space')]</code>.", td_style),
            Paragraph("Emitters dynamically spawn clones of their associated body during simulation:<br/>"
                      "• <b>Rate & Delay:</b> Spawn frequency interval (seconds) and initial countdown.<br/>"
                      "• <b>Lifetime:</b> Lifespan before emitted copies are automatically erased (0 = permanent).<br/>"
                      "• <b>Recoil:</b> Implements Newton's 3rd Law—applies opposite reaction impulse to the cannon body upon projectile launch.", td_style)
        ]
    ]
    prop_tbl = Table(prop_data, colWidths=[270, 270])
    prop_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), LIGHT_BG),
        ('BACKGROUND', (1,0), (1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white]),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(prop_tbl)
    story.append(Spacer(1, 2))

    # Page 6 Addition: Ruby Script API Cheat Sheet
    story.append(Paragraph("Ruby Scripting API Quick Reference (Body & Simulation Methods)", h2_style))
    api_data = [
        [Paragraph("Ruby API Method", th_style), Paragraph("Target Object", th_style), Paragraph("Function & Parameter Types", th_style), Paragraph("Example Usage & Context", th_style)],
        [
            Paragraph("<code>body.get_velocity</code> / <code>set_velocity(v)</code>", td_code),
            Paragraph("MSPhysics::Body", td_style),
            Paragraph("Gets or overrides linear velocity vector [vx, vy, vz] in m/s.", td_style),
            Paragraph("<code>body.set_velocity([0, 0, 10])</code> (Instant vertical jump)", td_style)
        ],
        [
            Paragraph("<code>body.add_force(f)</code> / <code>add_torque(t)</code>", td_code),
            Paragraph("MSPhysics::Body", td_style),
            Paragraph("Applies instantaneous force (Newtons) or rotational torque (N·m).", td_style),
            Paragraph("<code>body.add_force([0, 500, 0])</code> inside <code>onUpdate</code> hook", td_style)
        ],
        [
            Paragraph("<code>simulation.play_sound(path, pos)</code>", td_code),
            Paragraph("MSPhysics::Simulation", td_style),
            Paragraph("Plays 3D spatial audio file at given Point3d in model space.", td_style),
            Paragraph("<code>simulation.play_sound('hit.wav', contact.point)</code>", td_style)
        ],
        [
            Paragraph("<code>simulation.find_body_by_name(n)</code>", td_code),
            Paragraph("MSPhysics::Simulation", td_style),
            Paragraph("Finds active simulation Body instance by its SketchUp entity name.", td_style),
            Paragraph("<code>target = simulation.find_body_by_name('Turret')</code>", td_style)
        ]
    ]
    api_tbl = Table(api_data, colWidths=[150, 95, 145, 150])
    api_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, LIGHT_BG]),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(api_tbl)

    story.append(PageBreak())

    # =========================================================================
    # PAGE 7: REPLAY & KEYFRAME ANIMATION TOOLBAR
    # =========================================================================
    story.append(make_banner("SECTION 6: REPLAY & KEYFRAME ANIMATION TOOLBAR", "ANIMATION & EXPORT"))
    story.append(Spacer(1, 2))

    replay_intro = (
        "The <b>MSPhysics Replay Toolbar</b> is an enterprise-grade animation recording and playback suite. "
        "During live physics simulation, millions of calculations occur per second. Replay records every body transformation, "
        "velocity vector, and viewport camera movement into memory and persistent model attributes, enabling deterministic playback, "
        "camera choreography, and photorealistic raytraced rendering."
    )
    story.append(Paragraph(replay_intro, body_style))
    story.append(Spacer(1, 2))

    replay_tools_data = [
        [Paragraph("Tool & Icon", th_style), Paragraph("Command Name", th_style), Paragraph("Engine Function & Behavior", th_style), Paragraph("Operational Usage & Workflow", th_style), Paragraph("Impact & Notes", th_style)],
        [
            Table([[Image('MSPhysics/images/icons/replay_record.png', width=15, height=15), Paragraph("<b>Toggle Record</b>", td_bold)]], colWidths=[18, 77]),
            Paragraph("Record Armed<br/>(Toggle)", td_style),
            Paragraph("Enables recording mode. When active, every simulation frame captures body positions, orientations, and visibility states.", td_style),
            Paragraph("1. Click button (turns Checked).<br/>2. Press Toggle Play to run simulation.<br/>3. Replay data streams into buffer.", td_style),
            Paragraph("Captures full rigid body kinematics.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/replay_camera.png', width=15, height=15), Paragraph("<b>Camera Replay</b>", td_bold)]], colWidths=[18, 77]),
            Paragraph("Camera Tracking<br/>(Toggle)", td_style),
            Paragraph("Synchronously records SketchUp viewport camera eye, target, and up-vector during simulation alongside bodies.", td_style),
            Paragraph("1. Enable before pressing Play.<br/>2. Orbit/pan camera during physics run.<br/>3. Camera path replays automatically.", td_style),
            Paragraph("Enables cinematic camera fly-throughs.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/replay_play.png', width=15, height=15), Paragraph("<b>Play</b>", td_bold)]], colWidths=[18, 77]),
            Paragraph("Forward Playback<br/>(Action)", td_style),
            Paragraph("Plays recorded simulation timeline forward from current frame to the end of the captured sequence.", td_style),
            Paragraph("1. Reset simulation after recording.<br/>2. Click Replay Play to review motion.", td_style),
            Paragraph("Smooth interpolation at native FPS.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/replay_reverse.png', width=15, height=15), Paragraph("<b>Reverse</b>", td_bold)]], colWidths=[18, 77]),
            Paragraph("Backward Playback<br/>(Action)", td_style),
            Paragraph("Plays recorded animation backward in reverse time toward frame 0.", td_style),
            Paragraph("1. Click during or after replay.<br/>2. Useful for rewind effects and impact analysis.", td_style),
            Paragraph("Exact reverse kinematic trajectory.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/replay_pause.png', width=15, height=15), Paragraph("<b>Pause</b>", td_bold)]], colWidths=[18, 77]),
            Paragraph("Freeze Frame<br/>(Toggle)", td_style),
            Paragraph("Temporarily halts replay playback at the current frame without resetting timeline position.", td_style),
            Paragraph("1. Click to pause.<br/>2. Click Play or Reverse to resume.", td_style),
            Paragraph("Allows viewport inspection of any frame.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/replay_reset.png', width=15, height=15), Paragraph("<b>Reset</b>", td_bold)]], colWidths=[18, 77]),
            Paragraph("Rewind to 0<br/>(Action)", td_style),
            Paragraph("Stops replay playback and rewinds all model geometry and camera back to initial Frame 0.", td_style),
            Paragraph("Click to return model to starting positions.", td_style),
            Paragraph("Prepares timeline for re-playback.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/replay_stop.png', width=15, height=15), Paragraph("<b>Stop</b>", td_bold)]], colWidths=[18, 77]),
            Paragraph("Halt at Frame<br/>(Action)", td_style),
            Paragraph("Terminates replay playback but keeps objects at their current frame transforms (avoids resetting to 0).", td_style),
            Paragraph("Click when desired pose is reached.", td_style),
            Paragraph("Bakes replay frame into model geometry.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/replay_increase_speed.png', width=15, height=15), Paragraph("<b>Speed Adjust</b>", td_bold)]], colWidths=[18, 77]),
            Paragraph("Increase / Decrease<br/>(Step commands)", td_style),
            Paragraph("Dynamically scales playback speed multiplier from 0.01x (super slow-motion) up to 10.0x (high-speed fast-forward).", td_style),
            Paragraph("Click <b>Increase Speed</b> or <b>Decrease Speed</b>. Status bar displays current multiplier.", td_style),
            Paragraph("Real-time timescale modulation.", td_style)
        ],
        [
            Table([[Image('MSPhysics/images/icons/replay_destroy.png', width=15, height=15), Paragraph("<b>Clear Data</b>", td_bold)]], colWidths=[18, 77]),
            Paragraph("Purge Memory<br/>(Destructive)", td_style),
            Paragraph("Permanently erases all cached replay frame data from RAM and SketchUp model attributes.", td_style),
            Paragraph("1. Click when animation is no longer needed.<br/>2. Frees RAM and prevents large file size.", td_style),
            Paragraph("Reclaims storage space in model file.", td_style)
        ],
    ]
    replay_tbl = Table(replay_tools_data, colWidths=[95, 75, 140, 150, 80])
    replay_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, ALT_ROW]),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(replay_tbl)
    story.append(Spacer(1, 2))

    render_html = (
        "<b>Photorealistic Rendering & Video Export Workflow:</b><br/>"
        "1. <b>Export to Native SketchUp Scenes (Pages):</b> In MSPhysics Replay UI, click <i>'Export to Scenes'</i> to convert keyframes into native SketchUp animation tabs.<br/>"
        "2. <b>Raytraced Rendering:</b> Compatible with all major SketchUp render engines: <b>V-Ray, Enscape, Thea Render, Twilight Render, and Kerkythea</b>. "
        "The renderer advances through the scene tabs, generating photorealistic raytraced frames with full motion blur and global illumination.<br/>"
        "3. <b>Image Sequence / MP4 Export:</b> Export uncompressed PNG/JPEG sequences to compile broadcast-quality video animations."
    )
    render_tbl = Table([[Paragraph(render_html, callout_text)]], colWidths=[540])
    render_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), BLUE_BG),
        ('BOX', (0,0), (-1,-1), 0.8, SECONDARY),
        ('TOPPADDING', (0,0), (-1,-1), 2.2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2.2),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(render_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Production Export Pipelines & Memory Architecture", h2_style))
    pipe_data = [
        [
            Paragraph("<b>Replay Memory Budget & Data Serialization</b>", td_bold),
            Paragraph("<b>FFmpeg High-Definition Video CLI Pipeline</b>", td_bold)
        ],
        [
            Paragraph("• <b>RAM Buffer:</b> Replay stores transformations in efficient C++ native memory buffers during recording to prevent garbage-collector hitches.<br/>"
                      "• <b>Save to Model:</b> Commits frame records as serial binary attributes into the <code>.skp</code> model, allowing animation to persist across sessions.<br/>"
                      "• <b>Save to File:</b> Streams massive simulations directly to external <code>.mspr</code> replay files to avoid bloating model file size.", td_style),
            Paragraph("To composite raw frame images into standard 60 FPS ProRes / MP4 video:<br/>"
                      "<code>ffmpeg -framerate 60 -i frame_%05d.png -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p output.mp4</code><br/>"
                      "• Preserves exact frame cadence without frame drops.<br/>"
                      "• Lossless color fidelity matching SketchUp viewport outputs.", td_style)
        ]
    ]
    pipe_tbl = Table(pipe_data, colWidths=[270, 270])
    pipe_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), LIGHT_BG),
        ('BACKGROUND', (1,0), (1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white]),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(pipe_tbl)
    story.append(Spacer(1, 2))

    # Page 7 Addition: Major Renderer Compatibility Table
    render_compat_data = [
        [Paragraph("Rendering Engine", th_style), Paragraph("Integration Method", th_style), Paragraph("Motion Blur & Lighting", th_style), Paragraph("Recommended Settings", th_style)],
        [
            Paragraph("<b>Chaos V-Ray</b>", td_bold),
            Paragraph("Batch Scene Tab Rendering", td_style),
            Paragraph("Physical camera motion blur enabled", td_style),
            Paragraph("Disable scene transition delays; set frame interval to 1.0 frame.", td_style)
        ],
        [
            Paragraph("<b>Enscape 3D</b>", td_bold),
            Paragraph("Camera Path Video Sync", td_style),
            Paragraph("Real-time raytracing, screen space reflections", td_style),
            Paragraph("Lock time of day; enable Replay Camera tracking.", td_style)
        ],
        [
            Paragraph("<b>Thea / Twilight Render</b>", td_bold),
            Paragraph("Animation Timeline Exporter", td_style),
            Paragraph("Spectral unbiased path tracing", td_style),
            Paragraph("Export camera and geometry matrices; utilize GPU denoising.", td_style)
        ]
    ]
    render_compat_tbl = Table(render_compat_data, colWidths=[110, 130, 140, 160])
    render_compat_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, LIGHT_BG]),
        ('TOPPADDING', (0,0), (-1,-1), 1.4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.4),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(render_compat_tbl)

    story.append(PageBreak())

    # =========================================================================
    # PAGE 8: DEVELOPER, BUILD & DIAGNOSTIC TOOLS
    # =========================================================================
    story.append(make_banner("SECTION 7: DEVELOPER, BUILD & DIAGNOSTIC TOOLS", "BUILD CHAIN & TROUBLESHOOTING"))
    story.append(Spacer(1, 2))

    dev_intro = (
        "This repository contains the complete cross-compilation toolchain and automated testing harness that updated MSPhysics "
        "to run natively on <b>SketchUp 2024–2026 (Ruby 3.2 UCRT)</b>. "
        "Understanding these developer tools enables engineers to inspect native engine bindings, rebuild binary extensions, and diagnose runtime faults."
    )
    story.append(Paragraph(dev_intro, body_style))
    story.append(Spacer(1, 2))

    dev_tools_data = [
        [Paragraph("Tool / Script Path", th_style), Paragraph("System Role", th_style), Paragraph("Technical Mechanism & Pipeline", th_style), Paragraph("Execution Command & Requirements", th_style)],
        [
            Paragraph("<b>tools/prepare_sources.sh</b>", td_bold),
            Paragraph("Source Fetcher & Patch Applier", td_style),
            Paragraph("Downloads upstream Newton Dynamics 3.14 and SDL C++ sources; applies non-MSVC patches (<code>ruby_prep.h.patch</code>, <code>dgTypes.cpp.patch</code>) for GCC/Clang/Zig compatibility.", td_style),
            Paragraph("<code>tools/prepare_sources.sh [dest]</code><br/>Requires: <code>curl</code>, <code>tar</code>, <code>patch</code>", td_style)
        ],
        [
            Paragraph("<b>tools/build_win64_ruby32.sh</b>", td_bold),
            Paragraph("Zig C++ Cross-Compiler", td_style),
            Paragraph("Cross-compiles native extensions <code>msp_lib.so</code> and <code>newton.dll</code> targeting Windows x64 Ruby 3.2 (<code>x64-ucrt-ruby320</code>). "
                      "Uses Zig's Clang frontend to target <code>x86_64-windows-gnu</code> without requiring Microsoft Visual Studio.", td_style),
            Paragraph("<code>tools/build_win64_ruby32.sh</code><br/>Requires: <code>pip install ziglang</code>", td_style)
        ],
        [
            Paragraph("<b>native/harness/run_tests.sh</b>", td_bold),
            Paragraph("Ruby WASM Test Harness", td_style),
            Paragraph("Executes test suite on Ruby 3.2 inside WebAssembly (<code>ruby.wasm</code>) with a stubbed SketchUp 2026 API. "
                      "Validates syntax compilation, extension loading, AMS fallback routines, and DLL import dependencies.", td_style),
            Paragraph("<code>native/harness/run_tests.sh</code><br/>Requires: <code>node >= 18</code>, <code>@ruby/3.2-wasm-wasi</code>", td_style)
        ],
    ]
    dev_tbl = Table(dev_tools_data, colWidths=[120, 85, 205, 130])
    dev_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, ALT_ROW]),
        ('TOPPADDING', (0,0), (-1,-1), 1.8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.8),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(dev_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Built-in Diagnostic & Troubleshooting Systems", h2_style))
    diag_data = [
        [
            Paragraph("<b>Loader Hardening & ABI Verification</b>", td_bold),
            Paragraph("<b>PE Import Table Inspector (load_error.txt)</b>", td_bold)
        ],
        [
            Paragraph("<code>MSPhysics/main_entry.rb</code> intercepts extension loading. It verifies that AMS Library >= 3.8.0 is present and that a matching native binary exists for host Ruby ABI before invoking C++ libraries. Prevents silent SketchUp crashes and reports human-readable error dialogues.", td_style),
            Paragraph("If a DLL fails to load, MSPhysics directly parses the Portable Executable (PE) import table of <code>msp_lib.so</code>. It checks every dependency (<code>newton.dll</code>, <code>SDL2.dll</code>, <code>SDL2_mixer.dll</code>) and writes a comprehensive report to <code>MSPhysics/load_error.txt</code>.", td_style)
        ],
        [
            Paragraph("<b>AMS Library Self-Repair:</b> If cleanup scripts inadvertently delete <code>ruby_fallback.rb</code>, MSPhysics automatically restores it from <code>MSPhysics/ams_lib_fallback/</code> upon startup.", bullet_style),
            Paragraph("<b>Ruby 3.2 Compatibility:</b> Fully eliminates deprecated <code>File.exists?</code>, <code>Fixnum</code>, <code>Bignum</code>, and keyword argument splat syntax.", bullet_style)
        ]
    ]
    diag_tbl = Table(diag_data, colWidths=[270, 270])
    diag_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), LIGHT_BG),
        ('BACKGROUND', (1,0), (1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 1.6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.6),
        ('LEFTPADDING', (0,0), (-1,-1), 4),
        ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(diag_tbl)
    story.append(Spacer(1, 2))

    story.append(Paragraph("Master Keyboard & Operational Quick-Reference Matrix", h2_style))
    matrix_data = [
        [Paragraph("Key / Input", th_style), Paragraph("Context / Active Tool", th_style), Paragraph("Triggered Operational Action", th_style), Paragraph("Visual / Physics Feedback", th_style)],
        [Paragraph("<b>Spacebar / Click</b>", td_bold), Paragraph("Simulation Toolbar", td_style), Paragraph("Toggle Play / Pause simulation solver", td_style), Paragraph("Runs Newton dynamic integration / freezes time", td_style)],
        [Paragraph("<b>Left-Click Drag</b>", td_bold), Paragraph("Live Simulation Viewport", td_style), Paragraph("Picks and throws dynamic rigid body", td_style), Paragraph("Applies elastic spring force vector to cursor hit", td_style)],
        [Paragraph("<b>Shift + Drag</b>", td_bold), Paragraph("Live Simulation Viewport", td_style), Paragraph("Applies rotational torque to picked body", td_style), Paragraph("Tilts and twists body along angular cursor path", td_style)],
        [Paragraph("<b>W, S, A, D, Q, E</b>", td_bold), Paragraph("Live Simulation Viewport", td_style), Paragraph("6-Axis flying camera navigation", td_style), Paragraph("Translates camera forward, backward, strafe, elevate", td_style)],
        [Paragraph("<b>Arrow Keys</b>", td_bold), Paragraph("Live Simulation Viewport", td_style), Paragraph("Camera pan, tilt, and look-around", td_style), Paragraph("Rotates camera viewpoint angles", td_style)],
        [Paragraph("<b>Ctrl + Click</b>", td_bold), Paragraph("Joint Connection Tool", td_style), Paragraph("Binds selected body to clicked joint", td_style), Paragraph("Target joint highlights in Solid Green", td_style)],
        [Paragraph("<b>Shift + Click</b>", td_bold), Paragraph("Joint Connection Tool", td_style), Paragraph("Severs connection between body and joint", td_style), Paragraph("Removes constraint linkage", td_style)],
        [Paragraph("<b>Ctrl + Shift + Click</b>", td_bold), Paragraph("Joint Connection Tool", td_style), Paragraph("Toggles active connection state", td_style), Paragraph("Connects if severed; severs if connected", td_style)],
    ]
    matrix_tbl = Table(matrix_data, colWidths=[95, 115, 175, 155])
    matrix_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('BOX', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.3, BORDER_COL),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, ALT_ROW]),
        ('TOPPADDING', (0,0), (-1,-1), 1.4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.4),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(matrix_tbl)
    story.append(Spacer(1, 2))

    # Page 8 Addition: Top Troubleshooting Checklist
    trouble_html = (
        "<b>Top 5 Troubleshooting Solutions:</b> "
        "(1) <i>Engine Fails to Load:</i> Verify Ruby 3.2 UCRT binary is installed at <code>MSPhysics/libraries/stage/win64/3.2/msp_lib.so</code>. "
        "(2) <i>AMS Library Error:</i> Ensure AMS Library 3.8.0+ is active. "
        "(3) <i>SketchUp 2026.0 Matrix Inversion:</i> If singular transforms occur, MSPhysics auto-reverts to identity matrix. "
        "(4) <i>ShadowInfo KeyError in 2026.1+:</i> Extension automatically skips protected shadow attributes. "
        "(5) <i>Tunneling:</i> Enable Continuous Collision Detection (CCD) in Simulation settings."
    )
    trouble_tbl = Table([[Paragraph(trouble_html, callout_text)]], colWidths=[540])
    trouble_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 0.6, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(trouble_tbl)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Document successfully created: {filename}")

if __name__ == '__main__':
    build_pdf()
