import sys
import os
import logging
from PyQt5.QtWidgets import QApplication, QWidget, QVBoxLayout, QLineEdit, QPushButton, QLabel, QScrollArea, QHBoxLayout
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QCursor, QPixmap, QIcon
from pynput import keyboard
from embedding_utils import load_embeddings, semantic_search
from clip_model import generate_text_embedding

# Set up logging
logging.basicConfig(filename=os.path.expanduser('~/Desktop/query_app.log'), level=logging.DEBUG,
                    format='%(asctime)s - %(levelname)s - %(message)s')

class SearchThread(QThread):
    result_ready = pyqtSignal(list)
    error_occurred = pyqtSignal(str)

    def __init__(self, query_text):
        super().__init__()
        self.query_text = query_text

    def run(self):
        try:
            embeddings, image_paths = load_embeddings('image_index.bin')
            if embeddings is None or image_paths is None:
                raise ValueError("Error loading embeddings")

            query_embedding = generate_text_embedding(self.query_text)
            if query_embedding is None:
                raise ValueError("Error generating text embedding")

            _, result_images = semantic_search(query_embedding, embeddings, image_paths)
            self.result_ready.emit(result_images)
        except Exception as e:
            self.error_occurred.emit(str(e))


class QueryApp(QWidget):
    def __init__(self):
        super().__init__()
        self.init_ui()
        self.setup_global_hotkey()
        self.hide()
        logging.debug("Window initialized")

    def init_ui(self):
        self.setWindowTitle('Image Query')
        self.setFixedSize(600, 400)
        layout = QVBoxLayout()

        self.query_input = QLineEdit(self)
        self.query_input.setPlaceholderText("Enter your query")
        layout.addWidget(self.query_input)

        search_btn = QPushButton("Search", self)
        search_btn.clicked.connect(self.perform_search)
        layout.addWidget(search_btn)

        self.scroll_area = QScrollArea(self)
        self.scroll_area.setWidgetResizable(True)
        layout.addWidget(self.scroll_area)

        self.scroll_content = QWidget()
        self.scroll_layout = QVBoxLayout(self.scroll_content)
        self.scroll_area.setWidget(self.scroll_content)

        self.result_label = QLabel("", self)
        layout.addWidget(self.result_label)

        self.setLayout(layout)
        logging.debug("UI initialized")

    def setup_global_hotkey(self):
        def on_activate():
            logging.debug("Global hotkey activated")
            self.show_and_position_window()

        def for_canonical(f):
            return lambda k: f(listener.canonical(k))

        hotkey = keyboard.HotKey(
            keyboard.HotKey.parse('<cmd>+0'),
            on_activate)
        listener = keyboard.Listener(
            on_press=for_canonical(hotkey.press),
            on_release=for_canonical(hotkey.release))
        listener.start()
        logging.debug("Global hotkey set up")

    def show_and_position_window(self):
        if self.isVisible():
            logging.debug("Window is already visible, hiding it")
            self.hide()
        else:
            self.move_to_cursor()
            self.show()
            self.raise_()
            self.activateWindow()
            logging.debug("Window shown and positioned")

    def perform_search(self):
        query_text = self.query_input.text().strip()
        if not query_text:
            self.result_label.setText("Please enter a query.")
            return

        logging.debug(f"Performing search with query: {query_text}")
        self.result_label.setText("Searching...")  # Indicate that the search is in progress

        # Create and start the search thread
        self.thread = SearchThread(query_text)
        self.thread.result_ready.connect(self.display_results)
        self.thread.error_occurred.connect(self.handle_error)
        self.thread.start()

    def display_results(self, image_paths):
        # Clear previous results
        self.clear_results()

        if not image_paths:
            self.scroll_layout.addWidget(QLabel("No results found."))
            return

        for img_path in image_paths[:5]:  # Display top 5 similar images
            h_layout = QHBoxLayout()

            image_label = QLabel(self)
            pixmap = QPixmap(img_path)

            if pixmap.isNull():  # Check if the image loaded correctly
                logging.error(f"Failed to load image: {img_path}")
                continue  # Skip to the next image if loading fails

            pixmap = pixmap.scaled(150, 150, Qt.KeepAspectRatio)  # Scale image to 150x150 pixels
            image_label.setPixmap(pixmap)

            copy_button = QPushButton("Copy", self)
            copy_button.clicked.connect(lambda checked, path=img_path: self.copy_image(path))

            h_layout.addWidget(image_label)
            h_layout.addWidget(copy_button)
            self.scroll_layout.addLayout(h_layout)

    def clear_results(self):
        """Clear previous results from the scroll layout."""
        while self.scroll_layout.count():
            item = self.scroll_layout.takeAt(0)  # Get the item from the layout
            widget = item.widget()  # Get the associated widget
            if widget:
                widget.deleteLater()  # Delete the widget safely

    def handle_error(self, error_message):
        logging.error(f"Error during search: {error_message}")
        self.result_label.setText(f"Error: {error_message}")

    def copy_image(self, img_path):
        try:
            pixmap = QPixmap(img_path)

            if pixmap.isNull():
                raise ValueError("Could not load image.")

            clipboard = QApplication.clipboard()
            clipboard.setPixmap(pixmap)
            logging.debug(f"Copied image to clipboard: {img_path}")
        except Exception as e:
            logging.error(f"Error copying image: {str(e)}")

    def move_to_cursor(self):
        cursor_pos = QCursor.pos()
        screen = QApplication.primaryScreen().geometry()
        
        x = cursor_pos.x() - (self.width() // 2)
        y = cursor_pos.y() - (self.height() // 2)
        
        x = max(screen.left(), min(x, screen.right() - self.width()))
        y = max(screen.top(), min(y, screen.bottom() - self.height()))
        
        self.move(x, y)
        logging.debug(f"Moved window to position: ({x}, {y})")

    def closeEvent(self, event):
        event.ignore()
        self.hide()
        logging.debug("Window hidden instead of closed")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setWindowIcon(QIcon('sad.jpg'))  # Change to the path of your icon

    widget = QueryApp()
    logging.debug("Application starting...")
    widget.show()  # Show the app window normally
    sys.exit(app.exec_())
