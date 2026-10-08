"""
title: MiniMax H3 Video
description: Generate short text-to-video clips with MiniMax H3 on Halo's llama-swap.
author: mani
version: 1.0.0
license: MIT
"""

# Open WebUI has no video-generation engine, and llama-swap v249 has no
# first-class /v1/videos route, so this Tool drives Gufo's asynchronous
# OpenAI-style video API through llama-swap's generic upstream path. See
# docs/openwebui.md for installation (tools live in webui.db, not in Nix).
#
# minimax-h3 is a singleton llama-swap residency set: starting a job unloads
# the chat model that called this tool. llama-swap reloads that model for the
# reply after the video finishes.

import base64
import html
import io
import time
import asyncio
from typing import Awaitable, Callable, Optional

import aiohttp
from fastapi import UploadFile
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field


class Tools:
    class Valves(BaseModel):
        base_url: str = Field(
            default="http://127.0.0.1:9292/upstream/minimax-h3/v1",
            description="Gufo video API base, via llama-swap's upstream route.",
        )
        model: str = Field(default="minimax-h3", description="Gufo video model ID.")
        size: str = Field(
            default="512x512",
            description="512x512 or 1344x768 (Gufo's supported H3 canvases).",
        )
        poll_interval_seconds: int = Field(default=5, ge=1)
        timeout_seconds: int = Field(
            default=3600,
            description="Covers H3 cold load plus generation.",
        )
        max_inline_mb: int = Field(
            default=32,
            description="Largest MP4 embedded in the chat as a data URI.",
        )

    def __init__(self):
        self.valves = self.Valves()

    async def generate_video(
        self,
        prompt: str,
        seconds: int = 5,
        __user__: Optional[dict] = None,
        __request__=None,
        __metadata__: Optional[dict] = None,
        __event_emitter__: Optional[Callable[[dict], Awaitable[None]]] = None,
    ):
        """
        Generate a short video clip (with audio) from a text description using MiniMax H3.
        Use this whenever the user asks to create, generate or animate a video.
        :param prompt: A detailed visual description of the scene, subjects, motion, camera and sound.
        :param seconds: Clip length in seconds, from 5 to 14.
        :return: The generated video, embedded in the chat.
        """

        async def status(description: str, done: bool = False):
            if __event_emitter__:
                await __event_emitter__(
                    {
                        "type": "status",
                        "data": {"description": description, "done": done},
                    }
                )

        # Gufo rounds durations up to H3's 17n+5 frame grid; 15 s overflows
        # its 345-frame ceiling and is rejected.
        seconds = max(5, min(int(seconds), 14))
        base = self.valves.base_url.rstrip("/")
        timeout = aiohttp.ClientTimeout(total=None, sock_connect=30, sock_read=300)

        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                await status("Starting MiniMax H3 (loading can take several minutes)…")
                async with session.post(
                    f"{base}/videos",
                    json={
                        "model": self.valves.model,
                        "prompt": prompt,
                        "size": self.valves.size,
                        "seconds": seconds,
                    },
                ) as resp:
                    if resp.status == 429:
                        await status("H3 queue is full", done=True)
                        return "The video queue is full (one running, one queued). Try again later."
                    resp.raise_for_status()
                    job = await resp.json()

                job_id = job["id"]
                deadline = time.monotonic() + self.valves.timeout_seconds
                while job.get("status") not in ("completed", "failed", "cancelled"):
                    if time.monotonic() > deadline:
                        await session.delete(f"{base}/videos/{job_id}")
                        await status("Video generation timed out", done=True)
                        return f"Video job {job_id} timed out and was cancelled."
                    await asyncio.sleep(self.valves.poll_interval_seconds)
                    async with session.get(f"{base}/videos/{job_id}") as resp:
                        resp.raise_for_status()
                        job = await resp.json()
                    progress = job.get("progress")
                    suffix = f" {progress}%" if progress is not None else ""
                    await status(f"Generating video ({job.get('status')}){suffix}…")

                if job["status"] != "completed":
                    error = job.get("error") or {}
                    message = error.get("message") if isinstance(error, dict) else error
                    await status("Video generation failed", done=True)
                    return f"Video generation {job['status']}: {message or 'no details'}"

                await status("Downloading video…")
                async with session.get(f"{base}/videos/{job_id}/content") as resp:
                    resp.raise_for_status()
                    video = await resp.read()
        except aiohttp.ClientError as e:
            await status("Video generation failed", done=True)
            return f"Could not reach the video server: {e}"

        # Gufo deletes finished jobs after its TTL, so keep a downloadable copy
        # in Open WebUI's own file store. Failure here must not lose the clip.
        download_url = await self._store(video, job_id, __request__, __user__, __metadata__)

        size_mb = len(video) / (1024 * 1024)
        caption = html.escape(prompt)
        link = (
            f'<p><a href="{download_url}" target="_blank" rel="noopener">Download MP4</a></p>'
            if download_url
            else ""
        )
        # The embed is rendered in a sandboxed iframe without the session
        # cookie, so an authenticated file URL would not load inside it; a
        # data URI always does.
        if size_mb <= self.valves.max_inline_mb:
            src = "data:video/mp4;base64," + base64.b64encode(video).decode("ascii")
            player = f'<video controls playsinline style="max-width:100%" src="{src}"></video>'
        else:
            player = f"<p>Video is {size_mb:.1f} MiB, too large to embed.</p>"

        await status("Video ready", done=True)
        body = f'<div style="font-family:sans-serif">{player}<p>{caption}</p>{link}</div>'
        context = {
            "status": "success",
            "message": "The video is embedded and visible to the user.",
            "seconds": seconds,
            "size": self.valves.size,
            "download_url": download_url,
        }
        return (
            HTMLResponse(content=body, headers={"Content-Disposition": "inline"}),
            context,
        )

    async def _store(self, video, job_id, request, user, metadata) -> Optional[str]:
        if request is None or not user:
            return None
        try:
            from open_webui.models.users import Users
            from open_webui.routers.files import upload_file_handler

            user_model = await Users.get_user_by_id(user["id"])
            item = await upload_file_handler(
                request,
                file=UploadFile(
                    file=io.BytesIO(video),
                    filename=f"minimax-h3-{job_id}.mp4",
                    headers={"content-type": "video/mp4"},
                ),
                metadata={
                    "chat_id": (metadata or {}).get("chat_id"),
                    "message_id": (metadata or {}).get("message_id"),
                },
                process=False,
                user=user_model,
            )
            return request.app.url_path_for("get_file_content_by_id", id=item.id)
        except Exception:
            return None
