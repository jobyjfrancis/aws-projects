import { PollyClient, SynthesizeSpeechCommand } from "@aws-sdk/client-polly";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

// Initialize clients
const pollyClient = new PollyClient({});
const s3Client = new S3Client({});

export async function handler(event) {
    try {
        // Extract text input from the event
        const text = event.text;

        // Generate speech using Polly
        const pollyParams = {
            Text: text,
            OutputFormat: "mp3",
            VoiceId: "Joanna",
        };

        const synthesizeCommand = new SynthesizeSpeechCommand(pollyParams);
        const pollyResponse = await pollyClient.send(synthesizeCommand);

        // Validate Polly response
        if (!pollyResponse.AudioStream) {
            throw new Error("Polly did not return audio data.");
        }

        // Convert AudioStream to a buffer
        const audioBuffer = await streamToBuffer(pollyResponse.AudioStream);

        // Specify S3 parameters with ContentLength
        const key = `audio-${Date.now()}.mp3`;
        const s3Params = {
            Bucket: "amazon-polly-translated-audio-bucket-joby", // Replace with your S3 bucket name
            Key: key,
            Body: audioBuffer,
            ContentType: "audio/mpeg",
            ContentLength: audioBuffer.length, // Set content length explicitly
        };

        // Upload the audio file to S3
        const putCommand = new PutObjectCommand(s3Params);
        await s3Client.send(putCommand);

        return {
            statusCode: 200,
            body: JSON.stringify({ message: `Audio stored as ${key}` }),
        };
    } catch (error) {
        console.error("Error:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Internal server error", error: error.message }),
        };
    }
}

// Helper function: Convert a readable stream to a buffer
async function streamToBuffer(stream) {
    const chunks = [];
    for await (const chunk of stream) {
        chunks.push(chunk);
    }
    return Buffer.concat(chunks);
}