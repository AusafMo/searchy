import sys
import os
from index import index_images_from_folder  # Ensure this import works correctly

def main():
    if len(sys.argv) != 2:
        print("Usage: python make_index.py <folder_path>")
        sys.exit(1)

    folder_path = sys.argv[1]
    
    # Check if the provided path is a valid directory
    if not os.path.isdir(folder_path):
        print(f"Error: The specified path '{folder_path}' is not a valid directory.")
        sys.exit(1)

    # Logging
    with open('log.txt', 'w') as f:
        f.write("Index building started.\n")
        f.write(f"Indexing folder: {folder_path}\n")

    # Call the function to index images
    try:
        index_images_from_folder(folder_path)
        with open('log.txt', 'a') as f:
            f.write("Index building completed successfully.\n")
    except Exception as e:
        with open('log.txt', 'a') as f:
            f.write(f"Error occurred: {str(e)}\n")
        print(f"An error occurred while indexing: {e}")

if __name__ == "__main__":
    main()
