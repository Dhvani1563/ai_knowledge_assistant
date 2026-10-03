"""Step 2: split page text into retrievable chunks.

LangChain's RecursiveCharacterTextSplitter tries paragraph breaks first,
then lines, then sentences, then words — so chunks end at natural
boundaries. ~1000 chars (~200 tokens) with 150 overlap is a good start for
Q&A; tune CHUNK_SIZE / CHUNK_OVERLAP in .env and re-upload to compare.

Trade-off: we chunk *per page* so every chunk has an exact page number for
the citation UI. Text that spans a page break is not merged.
"""
from dataclasses import dataclass

from langchain_text_splitters import RecursiveCharacterTextSplitter

from ..core.config import settings
from .document_loader import LoadedPage


@dataclass
class Chunk:
    index: int
    page_number: int
    text: str


def chunk_pages(pages: list[LoadedPage]) -> list[Chunk]:
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=settings.chunk_size,
        chunk_overlap=settings.chunk_overlap,
        separators=["\n\n", "\n", ". ", " ", ""],
    )
    chunks: list[Chunk] = []
    for page in pages:
        for piece in splitter.split_text(page.text):
            piece = piece.strip()
            if len(piece) >= 30:  # drop page numbers, stray headers
                chunks.append(Chunk(index=len(chunks), page_number=page.page_number, text=piece))
    return chunks
