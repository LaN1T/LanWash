from urllib.parse import quote


def generate_sbp_url(amount: int, recipient_name: str) -> str:
    """Генерирует mock SBP-ссылку для оплаты чаевых.

    Для MVP без реального эквайрингового партнёра возвращаем
    универсальную ссылку с закодированными параметрами.
    """
    encoded_name = quote(recipient_name)
    return f"https://pay.example.com/sbp?amount={amount}&name={encoded_name}"
