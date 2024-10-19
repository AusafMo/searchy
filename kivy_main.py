import kivy
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.textinput import TextInput
from kivy.uix.label import Label
from kivy.uix.filechooser import FileChooserListView
from kivy.uix.popup import Popup
from PIL import Image
from clip_model import generate_text_embedding, generate_image_embedding
from embedding_utils import load_embeddings, semantic_search


class MyAppLayout(BoxLayout):
    def __init__(self, **kwargs):
        super(MyAppLayout, self).__init__(**kwargs)
        self.orientation = "vertical"

        # Text Query Section
        self.text_label = Label(text="Enter a text query:")
        self.add_widget(self.text_label)
        self.text_input = TextInput(hint_text="Type your text query here", multiline=False)
        self.add_widget(self.text_input)
        
        self.text_button = Button(text="Submit Text Query", on_press=self.text_query)
        self.add_widget(self.text_button)

        # Image Query Section
        self.image_button = Button(text="Select an Image for Query", on_press=self.open_image_chooser)
        self.add_widget(self.image_button)

    def text_query(self, instance):
        query_text = self.text_input.text.strip()
        if query_text:
            query_embedding = generate_text_embedding(query_text)
            if query_embedding is None:
                self.show_popup("Error", "Error generating text embedding.")
                return

            loaded_embeddings, loaded_image_paths = load_embeddings('image_index.bin')
            if loaded_embeddings is None or loaded_image_paths is None:
                self.show_popup("Error", "Could not load embeddings.")
                return

            result_text = semantic_search(query_embedding, loaded_embeddings, loaded_image_paths)
            self.show_popup("Results", result_text)

    def open_image_chooser(self, instance):
        filechooser = FileChooserListView(path='.', filters=['*.jpg', '*.png', '*.jpeg'])
        popup_content = BoxLayout(orientation='vertical')
        popup_content.add_widget(filechooser)
        select_button = Button(text="Select Image", on_press=lambda x: self.image_query(filechooser.path, filechooser.selection))
        popup_content.add_widget(select_button)

        self.popup = Popup(title="Select an Image", content=popup_content, size_hint=(0.9, 0.9))
        self.popup.open()

    def image_query(self, path, selection):
        if selection:
            query_image_path = selection[0]
            try:
                image = Image.open(query_image_path)
                query_embedding = generate_image_embedding(image)
                if query_embedding is None:
                    self.show_popup("Error", "Error generating image embedding.")
                    return

                loaded_embeddings, loaded_image_paths = load_embeddings('image_index.bin')
                if loaded_embeddings is None or loaded_image_paths is None:
                    self.show_popup("Error", "Could not load embeddings.")
                    return

                result_text = semantic_search(query_embedding, loaded_embeddings, loaded_image_paths)
                self.show_popup("Results", result_text)

            except Exception as e:
                self.show_popup("Error", f"Error processing image: {e}")
        self.popup.dismiss()

    def show_popup(self, title, message):
        # Display popups for errors or results
        popup = Popup(title=title, content=Label(text=message), size_hint=(0.8, 0.4))
        popup.open()


class MyApp(App):
    def build(self):
        return MyAppLayout()


if __name__ == "__main__":
    MyApp().run()
