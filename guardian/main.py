from __future__ import annotations

import asyncio

from aiogram import Bot, Dispatcher, F
from aiogram.filters import Command
from aiogram.types import Message

from config import settings
from monitor import HealthMonitor
from repair import RepairEngine

bot = Bot(settings.telegram_bot_token)
dp = Dispatcher()
monitor = HealthMonitor()
repair = RepairEngine()


def is_admin(message: Message) -> bool:
    return bool(message.chat and message.chat.id == settings.telegram_admin_chat_id)


def render_snapshot(results) -> str:
    lines = [f"GRU Guardian • mode: {settings.mode}"]
    for item in results:
        if item.ok:
            lines.append(f"🟢 {item.target}: HTTP {item.status} • {item.latency_ms} ms")
        else:
            detail = f"HTTP {item.status}" if item.status else (item.error or "unreachable")
            lines.append(f"🔴 {item.target}: {detail}")
    return "\n".join(lines)


@dp.message(Command("start"))
async def start(message: Message) -> None:
    if not is_admin(message):
        return
    await message.answer(
        "gru.guardian online.\n"
        "Commands: /status /repair_backend /repair_edge /policy"
    )


@dp.message(Command("status"))
async def status(message: Message) -> None:
    if not is_admin(message):
        return
    await message.answer(render_snapshot(await monitor.snapshot()))


@dp.message(Command("policy"))
async def policy(message: Message) -> None:
    if not is_admin(message):
        return
    await message.answer(
        f"Mode: {settings.mode}\n"
        f"Auto repair: {'enabled' if settings.can_repair else 'disabled'}\n"
        f"Code changes: {'enabled' if settings.can_code else 'disabled'}\n"
        f"Production changes: {'enabled' if settings.can_touch_production else 'disabled'}"
    )


@dp.message(Command("repair_backend"))
async def repair_backend(message: Message) -> None:
    if not is_admin(message):
        return
    ok, detail = await repair.safe_repair("backend")
    await message.answer(("🟢 " if ok else "🟠 ") + detail)


@dp.message(Command("repair_edge"))
async def repair_edge(message: Message) -> None:
    if not is_admin(message):
        return
    ok, detail = await repair.safe_repair("edge")
    await message.answer(("🟢 " if ok else "🟠 ") + detail)


async def watcher() -> None:
    while True:
        results = await monitor.snapshot()
        for result in results:
            failures = monitor.register(result)
            if result.ok:
                continue
            if failures == settings.failure_threshold:
                await bot.send_message(
                    settings.telegram_admin_chat_id,
                    f"🚨 GRU incident: {result.target} failed "
                    f"{failures} checks in a row.\n{render_snapshot(results)}"
                )
                if settings.can_repair:
                    ok, detail = await repair.safe_repair(result.target)
                    await bot.send_message(
                        settings.telegram_admin_chat_id,
                        ("🛠 Repair: " if ok else "⚠️ Repair skipped: ") + detail,
                    )
        await asyncio.sleep(settings.poll_seconds)


async def main() -> None:
    await bot.delete_webhook(drop_pending_updates=False)
    watcher_task = asyncio.create_task(watcher())
    try:
        await dp.start_polling(bot, allowed_updates=dp.resolve_used_update_types())
    finally:
        watcher_task.cancel()
        await bot.session.close()


if __name__ == "__main__":
    asyncio.run(main())
