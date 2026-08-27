from playwright.sync_api import sync_playwright
import pathlib, sys

url = "file://" + str(pathlib.Path("/home/claude/flowboard/flowboard-prototype.html").resolve())
errs = []

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": 1440, "height": 900})
    pg.on("console", lambda m: errs.append(f"console.{m.type}: {m.text}") if m.type == "error" else None)
    pg.on("pageerror", lambda e: errs.append(f"pageerror: {e}"))
    pg.goto(url)
    pg.wait_for_timeout(400)

    def check(label, cond):
        print(("PASS " if cond else "FAIL ") + label)
        if not cond: errs.append("assert failed: " + label)

    check("3 boards in sidebar", pg.locator("[data-board]").count() == 3)
    check("5 lists on board 1", pg.locator("[data-list]").count() == 5)
    n0 = pg.locator("[data-card]").count()
    check("cards rendered", n0 == 12)

    # open a card modal
    pg.locator("[data-card]").first.click()
    pg.wait_for_timeout(250)
    check("modal opens", pg.locator("#scrim.open").count() == 1)
    pg.fill("#mCheckNew", "Smoke test item"); pg.click("#mCheckAdd"); pg.wait_for_timeout(150)
    check("checklist item added", pg.locator("#mCheckItems .check-item").count() >= 1)
    pg.fill("#mComment", "Looks good."); pg.click("#mCommentSave"); pg.wait_for_timeout(150)
    check("comment added", "Looks good." in pg.inner_text("#mActivity"))
    pg.click("#aLabels"); pg.wait_for_timeout(120)
    check("label popup opens", pg.locator("#pop.open").count() == 1)
    pg.locator("#pop [data-l]").first.click(); pg.wait_for_timeout(150)
    pg.click("#mClose"); pg.wait_for_timeout(200)
    check("modal closes", pg.locator("#scrim.open").count() == 0)

    # add a card
    pg.locator("[data-add]").first.click(); pg.wait_for_timeout(120)
    pg.fill(".composer textarea", "Prototype smoke card")
    pg.click(".composer [data-save]"); pg.wait_for_timeout(200)
    check("card added", pg.locator("[data-card]").count() == n0 + 1)

    # search filter
    pg.fill("#searchInput", "smoke"); pg.wait_for_timeout(200)
    check("search filters", pg.locator("[data-card]").count() == 1)
    check("filter chip shown", pg.locator("#chipBar .chip").count() >= 1)
    pg.fill("#searchInput", ""); pg.wait_for_timeout(200)

    # board switch
    pg.locator("[data-board]").nth(1).click(); pg.wait_for_timeout(250)
    check("board 2 lists", pg.locator("[data-list]").count() == 3)
    pg.locator("[data-board]").nth(0).click(); pg.wait_for_timeout(250)

    # drag a card between lists
    src = pg.locator('[data-drop] [data-card]').first
    dst = pg.locator('[data-drop]').nth(2)
    src.drag_to(dst); pg.wait_for_timeout(400)

    # theme toggle
    pg.click("#themeBtn"); pg.wait_for_timeout(200)
    check("dark theme applied", pg.get_attribute("html", "data-theme") == "dark")
    pg.click("#themeBtn"); pg.wait_for_timeout(150)

    pg.screenshot(path="/home/claude/flowboard/preview-board.png")
    pg.locator("[data-card]").first.click(); pg.wait_for_timeout(300)
    pg.screenshot(path="/home/claude/flowboard/preview-card.png")
    b.close()

print("\n--- errors ---")
print("\n".join(errs) if errs else "none")
sys.exit(1 if errs else 0)
