import os, shlex, subprocess
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes

BOT_TOKEN = os.environ["BOT_TOKEN"]
ALLOWED = {int(s.strip()) for s in os.environ.get("ALLOWED_IDS","").split(",") if s.strip()}

def is_allowed(uid:int)->bool:
  return (not ALLOWED) or (uid in ALLOWED)

async def start(u:Update, c:ContextTypes.DEFAULT_TYPE):
  await u.message.reply_text("WireGuard bot\n/newclient <name>")

async def newclient(u:Update, c:ContextTypes.DEFAULT_TYPE):
  if not is_allowed(u.effective_user.id):
    return await u.message.reply_text("Not authorized.")
  if not c.args:
    return await u.message.reply_text("Usage: /newclient <name>")
  name = c.args[0]

  cmd = f"sudo -n /opt/wg/make_client.sh {shlex.quote(name)}"

  try:
    p = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
    lines = [x for x in p.stdout.splitlines() if x.strip()]

    conf = next(x.split(':',1)[1].strip() for x in lines if x.startswith("CONF:"))
    await u.message.reply_document(open(conf,"rb"), filename=f"{name}.conf")
    pngs = [x.split(':',1)[1].strip() for x in lines if x.startswith("PNG:")]
    if pngs:
      await u.message.reply_photo(open(pngs[0],"rb"), caption=f"{name} QR")
  except subprocess.CalledProcessError as e:
    await u.message.reply_text(f"Failed: {e.stderr or e.stdout or str(e)}")

def main():
  app = ApplicationBuilder().token(BOT_TOKEN).build()
  app.add_handler(CommandHandler("start",start))
  app.add_handler(CommandHandler("newclient",newclient))
  app.run_polling(close_loop=False)

if __name__ == "__main__":
  main()

