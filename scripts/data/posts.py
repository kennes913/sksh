# A simple script to handle generated fake content
import io
import mimesis
import os
import pathlib
import random
import shutil
import uuid

from datetime import date, timedelta
from inspect import getsource, ismethod

_source = pathlib.Path().absolute().parent.parent.joinpath("src/")

def generate_content(posts: int, days: int = 730) -> None:

    def _unsafe_file_removal(path: str) -> None:
        for file in os.listdir(path):
            os.remove(f"{path}/{file}")

    dest = _source.joinpath("content/posts")
    stream = io.StringIO()
    writer = mimesis.Text()
    today = date.today()

    _unsafe_file_removal(dest)

    for _, _ in enumerate(range(posts), 1):

        delta = timedelta(days=random.randrange(1, days + 1))
        written_date =  str(today - delta)
        publish_date = str(today - delta)
        title = f"{writer.word()}-{writer.word()}-{writer.word()}"
        category = random.choice(["python", "data", "docker","go","kubernetes"])

        hugo_front_matter = (
            f'---\n'
            f'title: "{title}"\n'
            f'date: {written_date}\n'
            f'publishdate: {publish_date}\n'
            f'layout: post\n'
            f'categories: ["{category}"]\n'
            f'---\n'
        )
        python_snippet = random.choice(
            [
                method
                for method in filter(
                    lambda x: ismethod(writer.__getattribute__(x)), dir(writer)
                )
            ]
        )
        code_snippet = (
            f"{{{{< highlight python >}}}}\n"
            f"{getsource(writer.__getattribute__(python_snippet))}\n"
            f"{{{{< /highlight >}}}}\n\n"
        )

        with open(f"{dest}/{uuid.uuid4().hex}.md", "w") as fd:

            fd.write(hugo_front_matter)
            for _ in range(3):
                fd.write(writer.text() + 2 * "\n")

            fd.write(code_snippet)
            fd.write(writer.text() + 2 * "\n")

        print(f"Post generated: {fd.name}")

generate_content(25)
