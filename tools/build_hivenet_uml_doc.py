"""Create the HiveNet UML assignment report and its diagram assets.

This builder deliberately keeps every diagram self-contained: it is suitable for
an academic submission and reflects the LAN image-replication implementation
in the accompanying HiveNet Flutter project.
"""

from __future__ import annotations

import math
import os
import sys
from pathlib import Path

EXTRA = os.environ.get("HIVENET_DOC_PACKAGES")
if EXTRA:
    sys.path.insert(0, EXTRA)

from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_ALIGN_VERTICAL, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "HiveNet_UML_Documentation.docx"
ASSET_DIR = ROOT / "_hivenet_uml_assets"
ASSET_DIR.mkdir(exist_ok=True)

NAVY = "17365D"
BLUE = "1F70A1"
PALE_BLUE = "D9EAF7"
PALE_GREEN = "E2F0D9"
PALE_ORANGE = "FCE4D6"
PALE_GRAY = "F2F2F2"
MID_GRAY = "666666"
WHITE = "FFFFFF"
BLACK = "000000"
BORDER = "A6A6A6"

FONT_REG = r"C:\Windows\Fonts\arial.ttf"
FONT_BOLD = r"C:\Windows\Fonts\arialbd.ttf"


def font(size: int, bold: bool = False):
    path = FONT_BOLD if bold else FONT_REG
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def image_canvas(width=1800, height=1040):
    return Image.new("RGB", (width, height), "white")


def text_size(draw, text, fnt):
    bb = draw.textbbox((0, 0), text, font=fnt)
    return bb[2] - bb[0], bb[3] - bb[1]


def wrap(draw, text, fnt, width):
    words = text.split()
    lines, current = [], ""
    for word in words:
        candidate = word if not current else current + " " + word
        if text_size(draw, candidate, fnt)[0] <= width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines or [""]


def multi_text(draw, xy, text, fnt, fill=BLACK, width=None, align="center", spacing=5):
    x, y = xy
    fill = fill if isinstance(fill, tuple) or str(fill).startswith("#") else "#" + str(fill)
    lines = []
    for paragraph in str(text).split("\n"):
        lines.extend(wrap(draw, paragraph, fnt, width) if width else [paragraph])
    line_height = text_size(draw, "Ag", fnt)[1] + spacing
    for line in lines:
        tw, _ = text_size(draw, line, fnt)
        lx = x
        if align == "center":
            lx = x - tw / 2
        elif align == "right":
            lx = x - tw
        draw.text((int(lx), int(y)), line, font=fnt, fill=fill)
        y += line_height
    return y


def rounded_box(draw, rect, label, fill=PALE_BLUE, outline=NAVY, title=None, small=False):
    x1, y1, x2, y2 = rect
    draw.rounded_rectangle(rect, radius=18, fill="#" + fill, outline="#" + outline, width=4)
    if title:
        draw.rounded_rectangle((x1, y1, x2, y1 + 46), radius=16, fill="#" + outline, outline="#" + outline)
        draw.rectangle((x1, y1 + 26, x2, y1 + 46), fill="#" + outline)
        multi_text(draw, ((x1 + x2) / 2, y1 + 9), title, font(24, True), WHITE, width=x2-x1-30)
        top = y1 + 58
    else:
        top = y1 + 14
    fnt = font(20 if small else 24, False)
    lines = []
    for part in label.split("\n"):
        lines += wrap(draw, part, fnt, x2 - x1 - 30)
    line_height = text_size(draw, "Ag", fnt)[1] + 5
    total = len(lines) * line_height
    sy = max(top, (y1 + y2 - total) / 2)
    multi_text(draw, ((x1 + x2) / 2, sy), "\n".join(lines), fnt, BLACK, width=x2-x1-30, spacing=5)


def ellipse(draw, rect, label, fill=PALE_BLUE, outline=NAVY, fsize=21):
    x1, y1, x2, y2 = rect
    draw.ellipse(rect, fill="#" + fill, outline="#" + outline, width=4)
    fnt = font(fsize)
    lines = wrap(draw, label, fnt, x2-x1-35)
    line_height = text_size(draw, "Ag", fnt)[1] + 4
    sy = (y1+y2-len(lines)*line_height)/2
    multi_text(draw, ((x1+x2)/2, sy), "\n".join(lines), fnt, BLACK, width=x2-x1-35, spacing=4)


def arrow(draw, p1, p2, label=None, color=NAVY, width=4, both=False, label_offset=-16):
    x1, y1 = p1
    x2, y2 = p2
    draw.line((x1, y1, x2, y2), fill="#" + color, width=width)
    angle = math.atan2(y2-y1, x2-x1)
    def head(x, y, a):
        length, spread = 16, math.pi/7
        pts = [(x, y),
               (x - length*math.cos(a-spread), y-length*math.sin(a-spread)),
               (x - length*math.cos(a+spread), y-length*math.sin(a+spread))]
        draw.polygon(pts, fill="#" + color)
    head(x2, y2, angle)
    if both:
        head(x1, y1, angle + math.pi)
    if label:
        mx, my = (x1+x2)/2, (y1+y2)/2
        multi_text(draw, (mx, my+label_offset), label, font(18), color, width=220)


def dashed_line(draw, p1, p2, color=MID_GRAY, width=3, dash=12):
    x1, y1 = p1; x2, y2 = p2
    length = math.hypot(x2-x1, y2-y1)
    steps = max(1, int(length/dash))
    for i in range(0, steps, 2):
        a, b = i/steps, min((i+1)/steps, 1)
        draw.line((x1+(x2-x1)*a, y1+(y2-y1)*a, x1+(x2-x1)*b, y1+(y2-y1)*b), fill="#"+color, width=width)


def actor(draw, center, label):
    x, y = center
    c = "#" + NAVY
    draw.ellipse((x-18, y-55, x+18, y-19), outline=c, width=4)
    draw.line((x, y-19, x, y+34), fill=c, width=4)
    draw.line((x-32, y+1, x+32, y+1), fill=c, width=4)
    draw.line((x, y+34, x-26, y+70), fill=c, width=4)
    draw.line((x, y+34, x+26, y+70), fill=c, width=4)
    multi_text(draw, (x, y+80), label, font(22, True), NAVY, width=170)


def save(im, name):
    path = ASSET_DIR / name
    im.save(path, "PNG", optimize=True)
    return path


def use_case_diagram():
    im = image_canvas(1800, 1010); d = ImageDraw.Draw(im)
    d.rounded_rectangle((330, 70, 1460, 930), radius=28, outline="#"+NAVY, width=5)
    multi_text(d, (360, 88), "HiveNet Application Boundary", font(27, True), NAVY, align="left")
    actor(d, (135, 320), "User")
    actor(d, (1655, 330), "Storage Node")
    actor(d, (135, 700), "Owner Device")
    cases = [
        ((510, 180, 790, 295), "Configure LAN peers"),
        ((950, 180, 1245, 295), "View node status"),
        ((510, 410, 790, 525), "Upload image or file"),
        ((950, 410, 1245, 525), "Download or retrieve"),
        ((510, 650, 790, 765), "Compress and encrypt"),
        ((950, 650, 1245, 765), "Select and replicate to two peers"),
        ((700, 815, 1050, 900), "Verify checksum and manage replicas"),
    ]
    for r, lab in cases: ellipse(d, r, lab)
    for pt in [(510,240),(950,240),(510,468),(950,468)]: arrow(d, (215,320), pt, color=MID_GRAY, width=3)
    arrow(d, (790,468), (950,468), "retrieve", color=MID_GRAY, width=3)
    arrow(d, (1245,708), (1575,380), "store or send replica", color=MID_GRAY, width=3)
    arrow(d, (215,700), (510,707), "owns keys", color=MID_GRAY, width=3)
    arrow(d, (650,525), (650,650), "includes", color=MID_GRAY, width=3)
    arrow(d, (1100,525), (1100,650), "includes", color=MID_GRAY, width=3)
    arrow(d, (1100,765), (940,815), "includes", color=MID_GRAY, width=3)
    return save(im, "01_use_case.png")


def class_diagram():
    im = image_canvas(1900, 1130); d = ImageDraw.Draw(im)
    classes = [
        ((55, 80, 470, 330), "User", "+ userId: String\n+ name: String\n+ upload()\n+ retrieve()\n+ configurePeer()"),
        ((730, 55, 1190, 340), "DistributedObject", "+ contentId: SHA 256\n+ originalBytes: long\n+ cipherBytes: long\n+ nonce: bytes\n+ state: ObjectState\n+ verify(bytes): bool"),
        ((1430, 80, 1840, 330), "StorageNode", "+ nodeId: String\n+ address: URI\n+ freeBytes: long\n+ latencyMs: int\n+ reliability: double\n+ store()\n+ fetch()"),
        ((60, 650, 470, 970), "FileManager", "+ prepareImage()\n+ compressImage()\n+ buildObject()\n+ reconstruct()\n+ validateHash()"),
        ((720, 650, 1200, 1010), "OwnerVault", "+ encrypt()\n+ decrypt()\n+ retainKey()\n+ retainDeleteToken()\n+ forget()"),
        ((1430, 635, 1840, 1000), "SmartRouter", "+ rankCandidates()\n+ scoreFor(bytes)\n+ selectReplicaPeers()\n+ recordOutcome()\n+ capacityWeight: 0.45\n+ latencyWeight: 0.25\n+ reliabilityWeight: 0.30"),
    ]
    for r, title, body in classes: rounded_box(d, r, body, PALE_BLUE, NAVY, title, small=True)
    arrow(d, (470,205), (730,195), "creates", both=False)
    arrow(d, (1190,195), (1430,205), "replicated to", both=False)
    arrow(d, (265,330), (265,650), "uses")
    arrow(d, (470,800), (720,800), "encrypts with")
    arrow(d, (1200,820), (1430,820), "ranks")
    arrow(d, (1190,300), (1430,635), "stored by", color=MID_GRAY, width=3)
    arrow(d, (470,840), (1430,890), "chooses peers for", color=MID_GRAY, width=3)
    multi_text(d, (950, 1080), "Association labels describe responsibility; StorageNode represents each participating LAN peer.", font(19), MID_GRAY, width=1600)
    return save(im, "02_class.png")


def sequence_diagram():
    im = image_canvas(1900, 1180); d = ImageDraw.Draw(im)
    parts = [(130,"User"),(420,"HiveNet App"),(730,"File Manager"),(1030,"Owner Vault"),(1310,"Smart Router"),(1580,"Peer B"),(1810,"Peer C")]
    for x, name in parts:
        rounded_box(d, (x-105, 35, x+105, 105), name, PALE_BLUE, NAVY, small=True)
        dashed_line(d, (x,105), (x,1120), MID_GRAY, 2, 14)
    steps = [
        (150, 130,420,"1. Select image"),
        (230, 420,730,"2. Compress and hash"),
        (310, 730,1030,"3. Encrypt and retain key"),
        (390, 730,1310,"4. Request two eligible peers"),
        (470, 1310,730,"5. Return ranked Peer B and Peer C"),
        (555, 730,1580,"6. PUT ciphertext with hash and token hash"),
        (635, 1580,730,"7. Atomic store and verified 201 acknowledgement"),
        (720, 730,1810,"8. PUT ciphertext with hash and token hash"),
        (800, 1810,730,"9. Atomic store and verified 201 acknowledgement"),
        (895, 730,420,"10. Persist replica locations and metrics"),
        (975, 420,130,"11. Report two verified replicas"),
    ]
    for y, sx, ex, label in steps:
        arrow(d, (sx,y), (ex,y), label, color=NAVY, width=3, label_offset=-28 if y % 2 else 12)
    multi_text(d, (950, 1080), "A successful upload requires two distinct checksum verified acknowledgements. A failed transfer is retried on the next eligible peer.", font(20), MID_GRAY, width=1640)
    return save(im, "03_sequence_upload.png")


def activity_diagram():
    im = image_canvas(1800, 1120); d = ImageDraw.Draw(im)
    # start/end nodes
    d.ellipse((830,40,870,80), fill="#"+NAVY)
    steps = [(690,120,1010,205,"Select image or file"),(690,255,1010,340,"Compress locally"),(690,390,1010,475,"Encrypt and calculate SHA 256"),(690,525,1010,610,"Probe and rank eligible nodes")]
    for x1, y1, x2, y2, lab in steps:
        rounded_box(d, (x1, y1, x2, y2), lab, PALE_BLUE, NAVY)
    for a,b in [((850,80),(850,120)),((850,205),(850,255)),((850,340),(850,390)),((850,475),(850,525))]: arrow(d,a,b)
    # Decision and peer branch
    d.polygon([(850,660),(1015,735),(850,810),(685,735)], fill="#"+PALE_ORANGE, outline="#"+NAVY, width=4)
    multi_text(d,(850,695),"Two eligible\n+peers?",font(23,True),NAVY,width=240)
    arrow(d,(850,610),(850,660))
    rounded_box(d,(100,675,500,805),"Show upload blocked. Ask user to connect two live peers.",PALE_ORANGE,NAVY)
    arrow(d,(685,735),(500,735),"No",label_offset=-28)
    rounded_box(d,(1180,675,1580,805),"Transfer to first available ranked peer.",PALE_BLUE,NAVY)
    arrow(d,(1015,735),(1180,735),"Yes",label_offset=-28)
    d.polygon([(1380,860),(1545,935),(1380,1010),(1215,935)], fill="#"+PALE_ORANGE, outline="#"+NAVY, width=4)
    multi_text(d,(1380,900),"Checksum\n+ack?",font(22,True),NAVY,width=220)
    arrow(d,(1380,805),(1380,860))
    rounded_box(d,(1540,870,1765,995),"Try next eligible peer and record failure.",PALE_ORANGE,NAVY,small=True)
    arrow(d,(1545,935),(1540,935),"No",label_offset=-24)
    rounded_box(d,(725,900,1060,1040),"Record replica location. Repeat until two verified replicas exist.",PALE_GREEN,NAVY)
    arrow(d,(1215,935),(1060,965),"Yes",label_offset=-24)
    arrow(d,(1540,995),(1060,1015),"retry",color=MID_GRAY,width=3,label_offset=16)
    d.ellipse((845,1060,935,1110), fill="#"+NAVY)
    multi_text(d,(890,1073),"Done",font(18,True),WHITE,width=100)
    arrow(d,(890,1040),(890,1060))
    return save(im, "04_activity_upload.png")


def dfd_diagram():
    im = image_canvas(1850, 1080); d = ImageDraw.Draw(im)
    actor(d,(160,330),"User")
    rounded_box(d,(540,160,1200,520),"HiveNet Node\n\n1. receive file selection\n2. compress and encrypt locally\n3. choose peers\n4. transfer and verify replicas\n5. retrieve through available replica",PALE_BLUE,NAVY,title="P0  HiveNet Decentralized Storage Process")
    rounded_box(d,(580,700,905,925),"D1 Owner Vault\nkeys, nonce and deletion token",PALE_GREEN,NAVY)
    rounded_box(d,(950,700,1275,925),"D2 Local Metadata\nobject IDs, replica locations, transfer history",PALE_GREEN,NAVY)
    rounded_box(d,(1440,180,1780,470),"External Peer Nodes\n\nfree space and status\nciphertext replicas\nverified acknowledgements",PALE_ORANGE,NAVY)
    arrow(d,(245,330),(540,300),"image, request")
    arrow(d,(540,390),(245,390),"status, result")
    arrow(d,(850,520),(745,700),"store key and token")
    arrow(d,(745,700),(720,520),"key for owned retrieve")
    arrow(d,(1015,520),(1110,700),"write replica map and metrics")
    arrow(d,(1110,700),(1110,520),"read locations")
    arrow(d,(1200,310),(1440,310),"encrypted object and protocol request")
    arrow(d,(1440,390),(1200,390),"status, data and acknowledgement")
    multi_text(d,(925,1010),"Level 0 DFD. The model has no central cloud database; D1 and D2 are local to the owner device.",font(20),MID_GRAY,width=1600)
    return save(im, "05_dfd_level0.png")


def er_diagram():
    im = image_canvas(1850, 1100); d = ImageDraw.Draw(im)
    entities = [
        ((60,170,400,420),"NODE","PK node_id\naddress\nfree_bytes\nlast_seen\nstatus"),
        ((600,100,1020,430),"OBJECT","PK content_id\noriginal_bytes\ncipher_bytes\nnonce\ncreated_at\nowner_node_id FK"),
        ((1390,170,1790,420),"REPLICA","PK replica_id\nobject_id FK\nnode_id FK\nverified_at\nstate"),
        ((610,680,1020,960),"TRANSFER_METRIC","PK metric_id\nnode_id FK\ncontent_id FK\nlatency_ms\noutcome\nrecorded_at"),
        ((50,700,420,950),"OWNER_CREDENTIAL","PK credential_id\ncontent_id FK\nkey_ref\ndelete_token_ref\nkept_in_secure_store"),
    ]
    for r,title,body in entities: rounded_box(d,r,body,PALE_BLUE,NAVY,title,small=True)
    arrow(d,(400,295),(600,265),"owns 1 to many",both=True)
    arrow(d,(1020,265),(1390,295),"has 1 to many",both=True)
    arrow(d,(400,365),(1390,365),"hosts 0 to many",color=MID_GRAY,width=3)
    arrow(d,(810,430),(810,680),"records",both=True)
    arrow(d,(400,820),(610,820),"protects 1 to 1",both=True)
    multi_text(d,(925,1045),"Conceptual local metadata design. Credentials are references to platform secure storage, not plaintext secrets in a shared database.",font(20),MID_GRAY,width=1640)
    return save(im, "06_er.png")


def architecture_diagram():
    im = image_canvas(1900, 1090); d = ImageDraw.Draw(im)
    # group cards
    d.rounded_rectangle((55,80,790,990),radius=25,outline="#"+NAVY,width=5)
    multi_text(d,(85,100),"Owner Device",font(27,True),NAVY,align="left")
    rounded_box(d,(115,180,720,310),"Flutter User Interface\nDashboard, upload, distributed gallery",PALE_BLUE,NAVY)
    rounded_box(d,(115,370,720,520),"Core Services\nFile Manager, Owner Vault, Smart Router, Replication Manager",PALE_GREEN,NAVY)
    rounded_box(d,(115,590,385,830),"Private File Store\ncompressed source and local replicas",PALE_GRAY,NAVY)
    rounded_box(d,(450,590,720,830),"Platform Secure Store\nper object keys and delete tokens",PALE_GRAY,NAVY)
    arrow(d,(420,310),(420,370),"commands and results")
    arrow(d,(300,520),(250,590),"files",color=MID_GRAY,width=3)
    arrow(d,(540,520),(585,590),"key references",color=MID_GRAY,width=3)
    d.rounded_rectangle((1040,190,1815,880),radius=25,outline="#"+NAVY,width=5)
    multi_text(d,(1070,210),"LAN Storage Peers",font(27,True),NAVY,align="left")
    rounded_box(d,(1100,320,1390,560),"Peer B Android Node Service\nHTTP over TCP 8765\natomic write and hash verification",PALE_ORANGE,NAVY)
    rounded_box(d,(1470,320,1760,560),"Peer C Android Node Service\nHTTP over TCP 8765\natomic write and hash verification",PALE_ORANGE,NAVY)
    rounded_box(d,(1100,650,1390,790),"B private filesystem\nciphertext and metadata",PALE_GRAY,NAVY)
    rounded_box(d,(1470,650,1760,790),"C private filesystem\nciphertext and metadata",PALE_GRAY,NAVY)
    arrow(d,(1245,560),(1245,650),"atomic move")
    arrow(d,(1615,560),(1615,650),"atomic move")
    # transport arrows
    arrow(d,(720,445),(1100,445),"encrypted PUT, GET, /v1/info",color=BLUE,width=5)
    arrow(d,(1100,510),(720,510),"verified acknowledgement or object",color=BLUE,width=5)
    multi_text(d,(930,950),"No central cloud service is required. Peer discovery is by configured LAN addresses and the web build acts as a client only.",font(20),MID_GRAY,width=1600)
    return save(im, "07_system_architecture.png")


def component_diagram():
    im = image_canvas(1850, 1110); d=ImageDraw.Draw(im)
    d.rounded_rectangle((55,55,1100,1010),radius=28,outline="#"+NAVY,width=5)
    multi_text(d,(85,78),"HiveNet Flutter Application",font(27,True),NAVY,align="left")
    components=[
        ((115,160,450,320),"User Interface\nHome, peer setup, gallery"),
        ((560,160,1000,320),"File Manager\ncompression, chunk preparation, integrity checks"),
        ((115,460,450,640),"Owner Vault\nAES 256 GCM and secure key references"),
        ((560,440,1000,640),"Smart Router\nprobe, score and choose two distinct peers"),
        ((335,760,780,930),"Replication Manager\nPUT and GET requests, acknowledgements, failover"),
    ]
    for r,lab in components: rounded_box(d,r,lab,PALE_BLUE,NAVY)
    arrow(d,(450,240),(560,240),"selected image")
    arrow(d,(285,320),(285,460),"protect")
    arrow(d,(780,320),(780,440),"candidate data")
    arrow(d,(780,640),(650,760),"targets")
    arrow(d,(450,560),(520,760),"ciphertext",color=MID_GRAY,width=3)
    d.rounded_rectangle((1270,155,1790,945),radius=28,outline="#"+NAVY,width=5)
    multi_text(d,(1300,178),"Peer Node Components",font(27,True),NAVY,align="left")
    rounded_box(d,(1330,300,1735,470),"Node Service\n/v1/info, /v1/files, CORS preflight" ,PALE_ORANGE,NAVY)
    rounded_box(d,(1330,585,1735,760),"Replica Store\nprivate files and JSON metadata",PALE_GRAY,NAVY)
    arrow(d,(1530,470),(1530,585),"verified atomic write")
    arrow(d,(1000,845),(1330,845),"HTTP protocol over LAN",color=BLUE,width=5)
    arrow(d,(1330,890),(1000,890),"data and status",color=BLUE,width=5)
    multi_text(d,(925,1045),"Components communicate through explicit interfaces; the router selects peers while the replication manager performs transfers and retry handling.",font(20),MID_GRAY,width=1600)
    return save(im,"08_component.png")


def deployment_diagram():
    im=image_canvas(1850,1080); d=ImageDraw.Draw(im)
    nodes=[
        ((70,120,610,880),"Device A Owner",[(130,235,550,380,"Flutter HiveNet App"),(130,460,325,650,"Secure Storage\nAES keys and tokens"),(355,460,550,650,"Private App Files\nsource and cache")]),
        ((760,180,1250,835),"Device B Peer",[(815,300,1195,455,"Android Foreground Node Service\nTCP port 8765"),(815,560,1195,720,"filesDir hivenet files\nopaque ciphertext")]),
        ((1400,180,1800,835),"Device C Peer",[(1450,300,1750,455,"Android Foreground Node Service\nTCP port 8765"),(1450,560,1750,720,"filesDir hivenet files\nopaque ciphertext")]),
    ]
    for outer,title,children in nodes:
        d.rounded_rectangle(outer,radius=28,outline="#"+NAVY,width=5)
        multi_text(d,(outer[0]+28,outer[1]+26),title,font(27,True),NAVY,align="left")
        for x1, y1, x2, y2, lab in children:
            rounded_box(d, (x1, y1, x2, y2), lab, PALE_BLUE if "App" in lab else PALE_GRAY, NAVY)
    arrow(d,(550,310),(815,355),"LAN HTTP PUT GET",color=BLUE,width=5)
    arrow(d,(550,370),(815,410),"hash verified acknowledgement",color=BLUE,width=4)
    arrow(d,(550,310),(1450,355),"LAN HTTP PUT GET",color=BLUE,width=5)
    arrow(d,(550,370),(1450,410),"hash verified acknowledgement",color=BLUE,width=4)
    arrow(d,(1005,455),(1005,560),"store",color=MID_GRAY,width=3)
    arrow(d,(1600,455),(1600,560),"store",color=MID_GRAY,width=3)
    multi_text(d,(925,970),"The owner selects two different reachable Android peers. If one replica becomes unavailable, retrieval uses the other verified location.",font(20),MID_GRAY,width=1600)
    return save(im,"09_deployment.png")


def state_diagram():
    im=image_canvas(1800,1050); d=ImageDraw.Draw(im)
    # nodes
    d.ellipse((80,455,125,500),fill="#"+NAVY)
    rounded_box(d,(250,390,520,530),"Offline\nNo successful probe",PALE_GRAY,NAVY)
    rounded_box(d,(710,150,1010,300),"Probing\nRequesting /v1/info",PALE_BLUE,NAVY)
    rounded_box(d,(710,430,1010,575),"Live\nEligible for routing",PALE_GREEN,NAVY)
    rounded_box(d,(1280,430,1550,575),"Busy\nTransfer in progress",PALE_ORANGE,NAVY)
    rounded_box(d,(710,760,1010,910),"Degraded\nRecent failure or low capacity",PALE_ORANGE,NAVY)
    d.ellipse((1630,455,1680,505),outline="#"+NAVY,width=5)
    d.ellipse((1642,467,1668,493),fill="#"+NAVY)
    arrow(d,(125,478),(250,460),"start or timeout")
    arrow(d,(520,420),(710,260),"probe scheduled")
    arrow(d,(860,300),(860,430),"reachable and enough free space")
    arrow(d,(1010,500),(1280,500),"selected for transfer")
    arrow(d,(1280,540),(1010,540),"verified acknowledgement")
    arrow(d,(860,575),(860,760),"failure or insufficient space")
    arrow(d,(710,835),(520,500),"next successful probe",color=MID_GRAY,width=3)
    arrow(d,(1550,500),(1630,480),"node removed")
    multi_text(d,(900,980),"Node state controls routing eligibility. Only Live peers with sufficient capacity are considered for replica placement.",font(20),MID_GRAY,width=1600)
    return save(im,"10_state_machine.png")


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def set_cell_margins(cell, top=110, start=110, bottom=110, end=110):
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcMar = tcPr.first_child_found_in("w:tcMar")
    if tcMar is None:
        tcMar = OxmlElement("w:tcMar")
        tcPr.append(tcMar)
    for m, v in (("top",top),("start",start),("bottom",bottom),("end",end)):
        node = tcMar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tcMar.append(node)
        node.set(qn("w:w"),str(v)); node.set(qn("w:type"),"dxa")


def set_cell_border(cell, color=BORDER, sz="8"):
    tcPr = cell._tc.get_or_add_tcPr()
    borders = tcPr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders"); tcPr.append(borders)
    for edge in ("top","left","bottom","right","insideH","insideV"):
        tag = qn(f"w:{edge}")
        elem = borders.find(tag)
        if elem is None:
            elem = OxmlElement(f"w:{edge}"); borders.append(elem)
        elem.set(qn("w:val"),"single"); elem.set(qn("w:sz"),sz); elem.set(qn("w:color"),color)


def add_text(doc, text, style=None, before=0, after=7, align=None, bold_prefix=None):
    p = doc.add_paragraph(style=style)
    p.paragraph_format.space_before = Pt(before)
    p.paragraph_format.space_after = Pt(after)
    p.paragraph_format.line_spacing = 1.15
    if align is not None: p.alignment = align
    if bold_prefix and text.startswith(bold_prefix):
        a=p.add_run(bold_prefix); a.bold=True
        p.add_run(text[len(bold_prefix):])
    else:
        p.add_run(text)
    return p


def add_bullets(doc, items):
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.1
        p.add_run(item)


def add_table(doc, headers, rows, widths=None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.autofit = False
    table.style = "Table Grid"
    for i, h in enumerate(headers):
        cell=table.rows[0].cells[i]
        cell.text=h; set_cell_shading(cell,NAVY); set_cell_margins(cell); set_cell_border(cell)
        cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
        for run in cell.paragraphs[0].runs:
            run.font.color.rgb=RGBColor(255,255,255); run.font.bold=True; run.font.size=Pt(9)
        if widths: cell.width=Inches(widths[i])
    for row_i,row in enumerate(rows):
        cells=table.add_row().cells
        for i,val in enumerate(row):
            cell=cells[i]; cell.text=val; set_cell_margins(cell); set_cell_border(cell)
            if row_i%2: set_cell_shading(cell,"EDF4FA")
            cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
            for p in cell.paragraphs:
                p.paragraph_format.space_after=Pt(0); p.paragraph_format.line_spacing=1.05
                for run in p.runs: run.font.size=Pt(9)
            if widths: cell.width=Inches(widths[i])
    doc.add_paragraph().paragraph_format.space_after=Pt(1)
    return table


def add_caption(doc, number, title, meaning):
    p=doc.add_paragraph()
    p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before=Pt(3); p.paragraph_format.space_after=Pt(4)
    r=p.add_run(f"Figure {number}. {title}."); r.bold=True; r.font.size=Pt(9)
    r=p.add_run(" " + meaning); r.italic=True; r.font.size=Pt(9)


def add_figure(doc, path, number, title, meaning, width=6.8):
    p=doc.add_paragraph()
    p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before=Pt(2); p.paragraph_format.space_after=Pt(0)
    p.add_run().add_picture(str(path),width=Inches(width))
    add_caption(doc,number,title,meaning)


def setup_document():
    doc=Document()
    sec=doc.sections[0]
    sec.page_width=Inches(8.5); sec.page_height=Inches(11)
    sec.left_margin=Inches(.78); sec.right_margin=Inches(.78)
    sec.top_margin=Inches(.72); sec.bottom_margin=Inches(.68)
    styles=doc.styles
    normal=styles["Normal"]; normal.font.name="Arial"; normal._element.rPr.rFonts.set(qn("w:ascii"),"Arial"); normal._element.rPr.rFonts.set(qn("w:hAnsi"),"Arial"); normal.font.size=Pt(10.5); normal.font.color.rgb=RGBColor(0,0,0)
    for name,size in [("Title",24),("Subtitle",12),("Heading 1",15),("Heading 2",12.5),("Heading 3",11)]:
        st=styles[name]; st.font.name="Arial"; st._element.rPr.rFonts.set(qn("w:ascii"),"Arial"); st._element.rPr.rFonts.set(qn("w:hAnsi"),"Arial"); st.font.size=Pt(size); st.font.color.rgb=RGBColor(0,0,0); st.font.bold=name!="Subtitle"
        st.paragraph_format.space_before=Pt(12 if name.startswith("Heading") else 0); st.paragraph_format.space_after=Pt(6)
    styles["Title"].paragraph_format.space_after=Pt(14)
    # footer page number field
    footer=sec.footer
    fp=footer.paragraphs[0]; fp.alignment=WD_ALIGN_PARAGRAPH.CENTER
    fld=OxmlElement("w:fldSimple"); fld.set(qn("w:instr"),"PAGE")
    fp._p.append(fld)
    for run in fp.runs: run.font.size=Pt(8); run.font.color.rgb=RGBColor(90,90,90)
    return doc


def hard_page_break(doc):
    p=doc.add_paragraph(); p.add_run().add_break(WD_BREAK.PAGE)


def build_report():
    figs={
        1:use_case_diagram(),2:class_diagram(),3:sequence_diagram(),4:activity_diagram(),5:dfd_diagram(),
        6:er_diagram(),7:architecture_diagram(),8:component_diagram(),9:deployment_diagram(),10:state_diagram(),
    }
    doc=setup_document()
    # Cover
    p=doc.add_paragraph(style="Title"); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    p.add_run("Design and UML Modeling of HiveNet Decentralized Peer to Peer Cloud Storage System")
    p=doc.add_paragraph(style="Subtitle"); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    p.add_run("Software Engineering UML Assignment")
    for _ in range(6): doc.add_paragraph()
    add_text(doc,"Prepared for UML and System Design Submission",align=WD_ALIGN_PARAGRAPH.CENTER,after=12)
    add_text(doc,"Project scope: encrypted LAN image replication with two verified peer replicas",align=WD_ALIGN_PARAGRAPH.CENTER,after=12)
    add_text(doc,"Prepared by: ________________________________",align=WD_ALIGN_PARAGRAPH.CENTER,after=8)
    add_text(doc,"Course: _________________________________",align=WD_ALIGN_PARAGRAPH.CENTER,after=8)
    add_text(doc,"Date: _________________________________",align=WD_ALIGN_PARAGRAPH.CENTER,after=8)
    hard_page_break(doc)
    # Executive overview
    doc.add_paragraph("Project Summary",style="Heading 1")
    add_text(doc,"HiveNet is a decentralized peer to peer storage application for devices on the same local network. It combines unused storage on participating devices without a cloud bucket, shared folder, or central database. In the implemented prototype, an owner selects an image, the application compresses and encrypts it on the owner device, and then places checksum verified ciphertext replicas on two distinct Android peers.")
    add_text(doc,"This document states the problem, defines the proposed solution, and presents the UML and system design needed to explain the architecture and behaviour. The diagrams use the current prototype as the design reference. The model can be extended from images to arbitrary files by applying the same prepare, encrypt, route, replicate, and retrieve workflow.")
    doc.add_paragraph("Document Scope",style="Heading 2")
    add_bullets(doc,[
        "Owner devices retain the decryption key and deletion capability. Storage peers receive ciphertext, an opaque content identifier, and the byte count needed to store it.",
        "Every successful upload has two distinct checksum verified peer acknowledgements. A peer failure triggers retry against the next eligible peer.",
        "Peers are manually configured by LAN address and expose a small HTTP service over TCP port 8765. The browser build is a client only and cannot host replicas.",
    ])
    doc.add_paragraph("Contents",style="Heading 2")
    add_bullets(doc,["Problem statement and objectives","Requirements and design decisions","Use case, class, sequence and activity diagrams","Data flow and database design","System architecture, component and deployment diagrams","Storage node state machine and conclusion"])
    # Problem statement
    doc.add_paragraph("Problem Statement",style="Heading 1")
    add_text(doc,"People create photographs, videos, and documents on many devices, but conventional cloud storage depends on a provider controlled server and may require paid capacity. At the same time, personal devices often have unused local disk space. The problem is to use this spare capacity across connected devices without turning one device into a permanent central server.")
    add_text(doc,"HiveNet addresses this problem by forming a decentralized storage network from participating devices. The system must upload, store, retrieve, and share objects across LAN peers; select suitable storage targets from live peers; reduce transfer size through client side compression; keep multiple replicas; and still retrieve a verified object when one replica is unavailable.")
    doc.add_paragraph("Objectives",style="Heading 2")
    add_table(doc,["ID","Objective"],[
        ("O1","Enable direct communication between multiple devices without a central cloud service."),
        ("O2","Use each participating device's private local filesystem as replica storage."),
        ("O3","Select peers using available capacity, probe latency, and prior verified transfer reliability."),
        ("O4","Compress an image before transfer and encrypt it before it leaves the owner device."),
        ("O5","Maintain two independent verified replicas so one unavailable peer does not make the object unavailable."),
        ("O6","Allow a user to configure peers, upload, inspect replica status, retrieve, and delete owned objects."),
    ],[.45,5.9])
    doc.add_paragraph("Proposed Solution",style="Heading 1")
    add_text(doc,"The HiveNet client prepares an image by constraining its longest edge, encoding it as a JPEG, and calculating a SHA 256 content identifier. The owner vault encrypts the prepared bytes with a unique AES 256 GCM key and retains the key, nonce, and deletion capability in platform secure storage. The smart router probes peers and scores only live nodes with enough free storage. It weights free capacity at 45 percent, latency at 25 percent, and reliability at 30 percent, then selects two different nodes.")
    add_text(doc,"Each selected peer receives an HTTP PUT request with ciphertext and its opaque identifier. It writes to a temporary file, calculates the hash as bytes arrive, atomically stores the object only when the hash matches, and returns a verified acknowledgement. The owner records replica locations and transfer history locally. Retrieval tries an available replica, verifies the returned hash, and decrypts only on a device that owns the key.")
    doc.add_paragraph("Key Design Constraints",style="Heading 2")
    add_table(doc,["Constraint","Design Response"],[
        ("No central database","Object locations and transfer history are stored locally and discovered from reachable peers."),
        ("Peer privacy","Only ciphertext and opaque content IDs leave the owner device; peers cannot preview images or recover filenames."),
        ("Fault tolerance","A success result is emitted only after two different peers acknowledge a verified replica."),
        ("Network variability","Offline, slow, low-capacity, or unreliable peers are excluded or ranked lower; next eligible peers are tried after a failure."),
        ("Platform boundary","Android peers can receive replicas through a foreground node service; the web build acts only as a client."),
    ],[1.55,4.8])
    # Requirements and mapping
    doc.add_paragraph("Requirements and Assumptions",style="Heading 1")
    add_table(doc,["Type","Requirement"],[
        ("Functional","The user can add LAN peer addresses, refresh peer health, upload an image, see replica locations, retrieve a verified image, and request deletion with the owner token."),
        ("Functional","The system must compress, encrypt, route, replicate, verify, and record transfer outcomes for an upload."),
        ("Nonfunctional","The owner must not report upload success unless two distinct peers have persisted matching ciphertext."),
        ("Nonfunctional","A peer must store only a complete object with a matching SHA 256 hash; partial writes are not published."),
        ("Assumption","At least two Android peers are reachable on the same LAN and have enough free capacity for the encrypted object."),
        ("Assumption","Manual LAN address configuration is acceptable for the MVP; automatic Internet discovery is outside the scope."),
    ],[1.25,5.1])
    doc.add_paragraph("Actors and Responsibilities",style="Heading 2")
    add_table(doc,["Actor or Component","Responsibility"],[
        ("User","Chooses content, manages peer configuration, requests upload or retrieval, and views outcome."),
        ("Owner Device","Prepares content, retains secrets, selects peers, coordinates replication, and validates retrieval."),
        ("Storage Node","Reports available capacity, receives and verifies opaque ciphertext, serves stored replicas, and accepts authenticated deletion."),
        ("Smart Router","Ranks peers by capacity, latency, and reliability, then provides two distinct eligible targets."),
        ("Replication Manager","Transfers objects, persists verified replica locations, retries after failure, and supports failover."),
    ],[2.0,4.35])
    # diagrams sections
    hard_page_break(doc)
    doc.add_paragraph("UML Diagrams",style="Heading 1")
    doc.add_paragraph("Use Case Diagram",style="Heading 2")
    add_text(doc,"The use case diagram identifies the people and devices that interact with HiveNet. The user starts visible actions, while a storage node supplies capacity and serves opaque replicas. The owner device is shown separately because it possesses secrets needed for encryption, decryption, and authenticated deletion.")
    add_figure(doc,figs[1],1,"Use Case Diagram","It shows the user and storage node interactions supported by the HiveNet application.",6.75)
    hard_page_break(doc)
    doc.add_paragraph("Class Diagram",style="Heading 2")
    add_text(doc,"The class diagram assigns the main responsibilities to domain and service classes. DistributedObject represents one protected object. FileManager performs content preparation, OwnerVault protects secrets, SmartRouter ranks eligible nodes, and StorageNode represents a remote peer. This separation keeps peer selection independent from encryption and transfer logic.")
    add_figure(doc,figs[2],2,"Class Diagram","It shows the major classes, important attributes, and responsibility relationships in the design.",6.75)
    hard_page_break(doc)
    doc.add_paragraph("Sequence Diagram for Upload",style="Heading 2")
    add_text(doc,"The upload sequence shows a complete success path. The router returns two distinct ranked peers, and the replication manager sends the same encrypted object to each. Both peers calculate the hash during their atomic write and send an acknowledgement only when the stored object matches. The client reports success only after it records two verified replicas.")
    add_figure(doc,figs[3],3,"Sequence Diagram for Upload","It describes the time ordered messages for image compression, encryption, routing, replication, and acknowledgement.",6.75)
    hard_page_break(doc)
    doc.add_paragraph("Activity Diagram for Upload",style="Heading 2")
    add_text(doc,"The activity diagram focuses on control flow and decision points. It blocks an upload when fewer than two eligible peers are available. During transfer, an unsuccessful acknowledgement causes the system to try a different eligible peer. Completion requires two checksum verified replica records.")
    add_figure(doc,figs[4],4,"Activity Diagram for Upload","It shows the workflow, decisions, and retry path that lead to two verified replicas.",6.65)
    hard_page_break(doc)
    # Design diagrams
    doc.add_paragraph("Data and System Design",style="Heading 1")
    doc.add_paragraph("Data Flow Diagram",style="Heading 2")
    add_text(doc,"The level 0 DFD shows the data boundary clearly. The owner device receives the selected image and keeps secret material in its local vault. Peer nodes receive only encrypted replicas. There is no central cloud data store: local metadata maps an object to its replica locations and transfer outcomes.")
    add_figure(doc,figs[5],5,"Data Flow Diagram Level 0","It traces data between the user, the HiveNet process, local owner data stores, and external peer nodes.",6.75)
    hard_page_break(doc)
    doc.add_paragraph("ER Diagram for Local Metadata",style="Heading 2")
    add_text(doc,"Although HiveNet deliberately avoids a central database, each owner can retain local metadata that supports routing and recovery. NODE records known peers. OBJECT records a protected object. REPLICA resolves the many to many placement relationship, and TRANSFER METRIC supplies the reliability history used by the router. OWNER CREDENTIAL contains only references to secrets kept in platform secure storage.")
    add_figure(doc,figs[6],6,"ER Diagram for Local Metadata","It defines the conceptual local data model and its object, replica, node, credential, and transfer relationships.",6.75)
    hard_page_break(doc)
    doc.add_paragraph("System Architecture Diagram",style="Heading 2")
    add_text(doc,"The architecture is distributed across an owner device and independent LAN peers. The owner runs the user interface and core services, preserves keys in secure storage, and stores only its own private files. Each Android peer runs a foreground node service and a private filesystem. Communication occurs through a small HTTP protocol, not through a cloud bucket or shared folder.")
    add_figure(doc,figs[7],7,"System Architecture Diagram","It shows the layered services and storage boundaries on the owner device and the two peer devices.",6.75)
    hard_page_break(doc)
    doc.add_paragraph("Component Diagram",style="Heading 2")
    add_text(doc,"The component diagram exposes module dependencies inside the Flutter application and peer service. The user interface delegates content handling to File Manager. The Owner Vault protects ciphertext preparation and controlled retrieval. Smart Router provides targets to Replication Manager, which uses the peer node HTTP interface for transfer and failover.")
    add_figure(doc,figs[8],8,"Component Diagram","It shows the application modules, their interfaces, and the LAN protocol connection to peer node components.",6.75)
    hard_page_break(doc)
    doc.add_paragraph("Deployment Diagram",style="Heading 2")
    add_text(doc,"The deployment diagram maps the software to physical devices in a minimum three-device setup. Device A is the owner and coordinator; Device B and Device C run the Android receiver. Each peer has its own filesystem and can be unavailable independently. This independence provides the basis for replica failover.")
    add_figure(doc,figs[9],9,"Deployment Diagram","It shows the owner and two Android storage peers connected across the local network.",6.75)
    hard_page_break(doc)
    doc.add_paragraph("State Machine Diagram",style="Heading 2")
    add_text(doc,"The state machine models a storage peer from the router's perspective. A peer becomes Live only after a successful probe establishes reachability and sufficient capacity. Selecting a Live peer moves it to Busy during a transfer. A transfer failure or loss of space moves it to Degraded until a successful future probe returns it to normal eligibility.")
    add_figure(doc,figs[10],10,"Storage Node State Machine Diagram","It describes how node connectivity and transfer outcomes control routing eligibility.",6.75)
    hard_page_break(doc)
    # Final design explanation
    doc.add_paragraph("How the Design Meets the Problem",style="Heading 1")
    add_table(doc,["Problem Need","HiveNet Design Response","Evidence in Model"],[
        ("Avoid dependency on a central cloud provider","Peers store replicas in their own private filesystem and exchange data directly over the LAN.","DFD, architecture, deployment"),
        ("Use suitable storage targets","Router filters live nodes with enough free space and ranks capacity, latency, and reliability.","Class, activity, state diagrams"),
        ("Prevent data loss from a peer failure","Two different peers must return checksum verified acknowledgements before success.","Sequence, activity, deployment diagrams"),
        ("Protect user content","Compression and AES 256 GCM encryption occur before the object leaves the owner; secrets stay in secure storage.","Class, component, architecture diagrams"),
        ("Retrieve trustworthy data","The client checks the content hash after fetch and tries another available verified replica on failure.","Sequence, component, state diagrams"),
    ],[1.35,3.3,1.3])
    doc.add_paragraph("Conclusion",style="Heading 1")
    add_text(doc,"HiveNet provides a concrete decentralized storage design for LAN connected devices. Its design combines client side compression, owner controlled encryption, capability based deletion, intelligent peer selection, atomic hash verified writes, and two peer replication. The diagrams in this report document both the static structure and the runtime behaviour needed to present the system as a complete UML assignment.")
    doc.add_paragraph("Suggested Demonstration Scenario",style="Heading 2")
    add_bullets(doc,[
        "Install HiveNet on three devices connected to the same LAN and configure each peer address on the owner device.",
        "Upload an image on Device A and show that Device B and Device C acknowledge stored opaque ciphertext with the same content hash.",
        "Turn off Device B, then retrieve the image from Device A to demonstrate failover through Device C.",
        "Show that a device without the owner key can store the replica but cannot decrypt or preview it.",
    ])
    # document properties
    doc.core_properties.title="Design and UML Modeling of HiveNet Decentralized Peer to Peer Cloud Storage System"
    doc.core_properties.subject="UML assignment documentation"
    doc.core_properties.author="HiveNet Project Team"
    doc.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    build_report()
