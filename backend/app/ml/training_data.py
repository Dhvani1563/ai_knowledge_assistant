"""Hand-labeled example questions for each of the four classes the pipeline
routes on. This is intentionally small (~120 examples) — enough for a
TF-IDF + Logistic Regression model to learn real lexical patterns rather
than memorizing keywords, and easy to extend as you collect real user
questions later (that's the natural next step: log real (question, chosen
label) pairs and retrain periodically).
"""

FACTUAL = [
    "What are the eligibility requirements?",
    "What is the minimum experience needed?",
    "When is the application deadline?",
    "How many vacation days do employees get?",
    "What is the salary range for this role?",
    "Who is the primary author of this paper?",
    "What year was this policy published?",
    "What is the maximum file size allowed?",
    "How long is the notice period?",
    "What certifications are required?",
    "What is the contact email for HR?",
    "How much does the premium plan cost?",
    "What is the warranty period for this product?",
    "What programming language is used in the backend?",
    "What is the office address?",
    "How many pages is this document?",
    "What is the refund policy?",
    "What time does the office open?",
    "What is the passing score for this exam?",
    "Who approved this budget?",
    "What license is required for this software?",
    "What is the interest rate mentioned in the contract?",
    "How many employees does the company have?",
    "What is the model number of this device?",
    "What is the expiry date on this agreement?",
    "What GPA is required for admission?",
    "What is the maximum load capacity?",
    "Who is the point of contact for this project?",
    "What is the tax rate applied here?",
    "What version of the API is currently supported?",
]

SUMMARIZATION = [
    "Summarize this document in 5 bullet points.",
    "Can you give me a TL;DR of this report?",
    "Summarize the key findings of this research paper.",
    "Give me an overview of the employee handbook.",
    "Condense this manual into the main steps.",
    "What's the gist of this contract?",
    "Provide a brief summary of chapter 3.",
    "Summarize the main arguments in this paper.",
    "Give me a short recap of this document.",
    "Can you summarize the terms and conditions?",
    "Explain the main points of this policy briefly.",
    "Summarize this resume in a few lines.",
    "What are the highlights of this quarterly report?",
    "Give me the abstract of this paper in plain English.",
    "Summarize the conclusions section.",
    "Provide an executive summary of this proposal.",
    "Boil this down to the essentials.",
    "Give me a one-paragraph summary of the manual.",
    "Summarize what this section covers.",
    "What's the overall takeaway from this document?",
    "Condense the eligibility section into a short summary.",
    "Summarize this in simple terms for a beginner.",
    "Give a high-level overview of the methodology used.",
    "Summarize the results section of this paper.",
    "What's a quick summary of the onboarding process?",
]

COMPARISON = [
    "Compare the two policies mentioned in this document.",
    "What's the difference between plan A and plan B?",
    "How does this year's report compare to last year's?",
    "Compare the eligibility requirements across both documents.",
    "What are the differences between these two resumes?",
    "Compare the pricing plans in this manual.",
    "How does this approach differ from the previous method?",
    "Compare the pros and cons of both options.",
    "What distinguishes version 1 from version 2?",
    "Compare the findings of these two research papers.",
    "How do the two contracts differ in terms of duration?",
    "Compare the qualifications of these two candidates.",
    "What's the difference in cost between these two vendors?",
    "Compare the safety guidelines in both manuals.",
    "How does this policy compare to industry standards?",
    "Compare the performance metrics between these two systems.",
    "What are the key differences between these documents?",
    "Compare the leave policy for full-time vs part-time staff.",
    "How do these two proposals compare in scope?",
    "Compare the warranty terms of both products.",
]

RETRIEVAL = [
    "Find every mention of the word deadline.",
    "Show me all sections about data privacy.",
    "List all the requirements mentioned in this document.",
    "Where is the termination clause located?",
    "Find all references to the budget.",
    "Show me every clause related to confidentiality.",
    "List all the certifications mentioned across my documents.",
    "Where can I find the refund policy?",
    "Find all instances of the term liability.",
    "Show me all the action items in this document.",
    "List every deliverable mentioned in the contract.",
    "Where is the section about employee benefits?",
    "Find all mentions of GDPR compliance.",
    "Show me every table in this report.",
    "List all the risks identified in this document.",
    "Where does it talk about payment terms?",
    "Find all the dates mentioned in this contract.",
    "Show me every reference to the previous version.",
    "List all the tools mentioned in the manual.",
    "Where is the escalation process described?",
]


def get_training_data() -> tuple[list[str], list[str]]:
    texts: list[str] = []
    labels: list[str] = []
    for text in FACTUAL:
        texts.append(text)
        labels.append("factual")
    for text in SUMMARIZATION:
        texts.append(text)
        labels.append("summarization")
    for text in COMPARISON:
        texts.append(text)
        labels.append("comparison")
    for text in RETRIEVAL:
        texts.append(text)
        labels.append("retrieval")
    return texts, labels
