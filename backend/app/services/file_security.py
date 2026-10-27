"""Safe handling of uploaded files: validate, store with tight permissions,
and (optionally) encrypt at rest.

Validation checks what the file REALLY is (its first bytes), not what its
name claims, so "virus.exe" renamed to "report.pdf" is rejected.

Encryption: if FILE_ENCRYPTION_KEY is set, every upload is encrypted with
Fernet (AES-128-CBC + HMAC) before it rests on disk. Anyone who copies the
uploads folder or a disk backup gets unreadable bytes. IMPORTANT: if you
lose the key, those files can never be decrypted.
"""
import contextlib
import os
import re
import tempfile
import zipfile

from ..core.config import settings


class UploadRejected(Exception):
    """The upload failed a security check; the message is safe to show the user."""


_CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def sanitize_display_name(filename: str | None) -> str:
    """A safe name to show in the UI (the file itself is stored under a random UUID)."""
    name = os.path.basename((filename or "").replace("\\", "/"))
    name = _CONTROL.sub("", name).strip().lstrip(".")
    name = re.sub(r"\s+", " ", name)
    if len(name) > 150:
        root, dot, ext = name.rpartition(".")
        name = (root[:140] + dot + ext[:8]) if dot else name[:150]
    return name or "document"


def validate_head(extension: str, head: bytes) -> None:
    """Check the first bytes of the upload match the claimed type."""
    if not head:
        raise UploadRejected("The file is empty.")
    if extension == "pdf":
        if not head.lstrip().startswith(b"%PDF-"):
            raise UploadRejected("This file is not a real PDF.")
    elif extension == "docx":
        if not head.startswith(b"PK\x03\x04"):
            raise UploadRejected("This file is not a real Word (.docx) document.")
    elif extension in ("txt", "md"):
        if b"\x00" in head:
            raise UploadRejected("This looks like a binary file, not text.")


def validate_saved_file(path: str, extension: str) -> None:
    """Deeper checks once the file is on disk (before it is ever parsed)."""
    if extension != "docx":
        return
    try:
        with zipfile.ZipFile(path) as archive:
            if "word/document.xml" not in archive.namelist():
                raise UploadRejected("This file is not a valid Word document.")
            unpacked = sum(info.file_size for info in archive.infolist())
    except zipfile.BadZipFile:
        raise UploadRejected("This Word document is corrupted.")
    if unpacked > settings.max_unpacked_mb * 1024 * 1024:
        raise UploadRejected("This document expands to an unsafe size when opened.")


def restrict_permissions(path: str) -> None:
    """Owner read/write only (has no effect on Windows; fine on Linux/macOS servers)."""
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def _fernet():
    key = (settings.file_encryption_key or "").strip()
    if not key:
        return None
    from cryptography.fernet import Fernet
    return Fernet(key.encode())


def check_encryption_key() -> bool:
    """Called at startup. Returns True if encryption is on; raises on a malformed key."""
    try:
        return _fernet() is not None
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(
            "FILE_ENCRYPTION_KEY is not a valid key. Generate one with: "
            "python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""
        ) from exc


def encrypt_file(path: str) -> bool:
    """Encrypts the file in place. Returns False when no key is configured."""
    fernet = _fernet()
    if fernet is None:
        return False
    with open(path, "rb") as src:
        data = src.read()
    with open(path, "wb") as dst:
        dst.write(fernet.encrypt(data))
    return True


@contextlib.contextmanager
def decrypted_copy(path: str, file_type: str):
    """Yields the path of a temporary plaintext copy, deleted on exit."""
    fernet = _fernet()
    if fernet is None:
        raise ValueError("This document is encrypted but FILE_ENCRYPTION_KEY is not set on the server.")
    from cryptography.fernet import InvalidToken
    with open(path, "rb") as src:
        try:
            plain = fernet.decrypt(src.read())
        except InvalidToken:
            raise ValueError("Could not decrypt this file. Was FILE_ENCRYPTION_KEY changed?")
    fd, tmp = tempfile.mkstemp(suffix=f".{file_type}")
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(plain)
        yield tmp
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass
