# save this as make_index.py
import sys
from index import index_images_from_folder  # Make sure this imports correctly

def main():
    if len(sys.argv) != 2:
        print("Usage: python make_index.py <folder_path>")
        sys.exit(1)

    folder_path = sys.argv[1]
    index_images_from_folder(folder_path)

if __name__ == "__main__":
    main()
