# Import every model so Base.metadata.create_all() sees all tables.
from .user import User  # noqa: F401
from .document import Document, DocumentStatus  # noqa: F401
from .chat import ChatSession, ChatMessage, MessageSender, QuestionType  # noqa: F401
