#!/usr/bin/env python

class Files:
    @classmethod
    def from_dir(cls, root):
        ...

def main():
    new_dir = ...
    prod_dir = ...

    new_version = get_version(new_dir)
    prod_version = get_version(prod_dir)

    prod_files = Files.from_dir(prod_dir)
    new_files = Files.from_dir(new_dir)

main()
